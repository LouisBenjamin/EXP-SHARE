-- TALLY — bank statement import
--
-- Privacy boundary. Raw statement data never reaches this database: the CSV is
-- parsed on the device and held in memory for the review screen only. Exactly
-- two things cross the wire.
--
--   1. merchant_rules — group-synced tagging presets. Merchant *name patterns*
--      only: no amounts, no dates, no reference numbers, no card numbers.
--      Group-scoped so everyone sharing a card tags the same merchant the same
--      way instead of each person re-tagging it every month.
--
--   2. expenses.source_fingerprint — an opaque SHA-256 of
--      (group_id || ':' || normalized reference number), computed client-side.
--      One-way: nothing about the merchant, amount, card or date is
--      recoverable from it. It exists so that when two roommates import
--      overlapping copies of the same shared-card statement from two devices,
--      the second import is recognised instead of charging the group twice.
--
-- The hash is deliberately computed on the client. Computing it here would
-- require sending the reference number to the server, which is the exact thing
-- this design exists to avoid. The server therefore cannot verify the digest
-- and simply trusts it; the blast radius of a bad one is a group the caller is
-- already a member of.
--
-- Note migration 0010 (group photos) is a sibling on another branch; this file
-- takes 0011 so the two don't collide whichever order they land.

-- ---------------------------------------------------------------- rules
create table merchant_rules (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  -- Uppercased merchant fragment, e.g. 'COSTCO WHOLESALE'. Matched as a
  -- substring, not compared for equality: the same warehouse appears as
  -- 'COSTCO WHOLESALE W515' and 'W521', and processors prepend their own tag.
  pattern     text not null check (length(trim(pattern)) > 0),
  match_type  text not null default 'contains'
                check (match_type in ('contains', 'prefix', 'exact')),
  category_id uuid references categories(id),
  -- 'share' = offer the row for import; 'skip' = never offer it.
  action      text not null default 'share' check (action in ('share', 'skip')),
  -- Lower wins. Ties are broken client-side by longer pattern, so a narrow
  -- rule beats a broad one without the user tuning numbers.
  priority    int not null default 100,
  created_by  uuid not null references profiles(id),
  created_at  timestamptz not null default now(),
  unique (group_id, pattern, match_type)
);

create index merchant_rules_group_idx on merchant_rules (group_id, priority);

alter table merchant_rules enable row level security;

create policy "members read merchant rules" on merchant_rules
  for select using (is_group_member(group_id));

create policy "members add merchant rule" on merchant_rules
  for insert with check (is_group_member(group_id) and created_by = auth.uid());

create policy "members update merchant rule" on merchant_rules
  for update using (is_group_member(group_id));

create policy "members delete merchant rule" on merchant_rules
  for delete using (is_group_member(group_id));

-- ---------------------------------------------------------------- fingerprint
alter table expenses add column source_fingerprint text;

-- Partial unique index, scoped to live imported rows on purpose:
--   * source_fingerprint is not null — hand-entered expenses are unconstrained,
--     and many nulls are allowed.
--   * deleted_at is null — a mis-imported expense that was deleted can be
--     imported again. Without this the soft-deleted row would block its own
--     transaction forever, with no visible expense to explain why. The
--     trade-off is that delete-then-reimport does create a second expense;
--     that is intended, not a bug.
create unique index expenses_source_fingerprint_key
  on expenses (group_id, source_fingerprint)
  where source_fingerprint is not null and deleted_at is null;

-- ---------------------------------------------------------------- commit
-- Promote reviewed statement rows into expenses + splits.
--
-- An RPC rather than client-side inserts because it gives atomicity (an
-- expense and its splits land together), it re-checks the splits-sum-to-amount
-- invariant server-side exactly as update_expense does, and — the reason a
-- plain insert wouldn't do — it lets a duplicate be *reported* rather than
-- raised. Someone else having already imported the statement is a normal
-- outcome, not an error.
--
-- p_items: jsonb array of
--   { fingerprint, payer_member_id, amount, description, occurred_on,
--     category_id?, split_type, splits: [{member_id, share_amount, share_percent?}] }
--
-- Returns { "inserted": n, "skipped": m, "skipped_fingerprints": [...] }.
-- The client marks both inserted and skipped fingerprints as imported, so a
-- duplicate is never offered again on that device either.
--
-- WARNING: the `on conflict` clause below repeats the predicate of
-- expenses_source_fingerprint_key verbatim. Postgres will not infer a partial
-- unique index as a conflict arbiter otherwise, and the mismatch surfaces at
-- runtime, not at migration time. Keep the two in sync.
create or replace function import_expenses(p_group_id uuid, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item        jsonb;
  v_expense_id  uuid;
  v_amount      numeric(12, 2);
  v_sum         numeric(12, 2);
  v_fingerprint text;
  v_label       text;
  v_inserted    int    := 0;
  v_skipped     text[] := '{}';
  v_index       int    := 0;
begin
  if not is_group_member(p_group_id) then
    raise exception 'Not a member of this group' using errcode = '42501';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Nothing to import';
  end if;

  -- Backstop against one oversized statement timing out the request. The
  -- client chunks; this is the guard rail.
  if jsonb_array_length(p_items) > 200 then
    raise exception 'Import at most 200 transactions at a time (got %)',
      jsonb_array_length(p_items);
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_index       := v_index + 1;
    v_expense_id  := null;
    v_fingerprint := v_item->>'fingerprint';
    v_amount      := (v_item->>'amount')::numeric;
    v_label       := coalesce(nullif(v_item->>'description', ''), 'unnamed');

    if coalesce(v_fingerprint, '') = '' then
      raise exception 'Transaction % is missing its fingerprint', v_index;
    end if;

    -- expenses.amount has check (amount > 0). A statement credit must never
    -- reach here, or the user meets a raw check violation instead of a
    -- sentence. The parser and the plan builder both guard this first.
    if v_amount is null or v_amount <= 0 then
      raise exception 'Transaction % (%) must have a positive amount',
        v_index, v_label;
    end if;

    select coalesce(sum((s->>'share_amount')::numeric), 0)
    into   v_sum
    from   jsonb_array_elements(v_item->'splits') s;

    if v_sum <> v_amount then
      raise exception 'Splits (%) must sum to amount (%) on transaction % (%)',
        v_sum, v_amount, v_index, v_label;
    end if;

    if not exists (
      select 1 from group_members
      where  id = (v_item->>'payer_member_id')::uuid and group_id = p_group_id
    ) then
      raise exception 'The payer on transaction % (%) is not a member of this group',
        v_index, v_label;
    end if;

    insert into expenses (
      group_id, payer_member_id, amount, category_id, description,
      occurred_on, split_type, created_by, source_fingerprint
    )
    values (
      p_group_id,
      (v_item->>'payer_member_id')::uuid,
      v_amount,
      nullif(v_item->>'category_id', '')::uuid,
      coalesce(v_item->>'description', ''),
      (v_item->>'occurred_on')::date,
      coalesce(nullif(v_item->>'split_type', ''), 'equal'),
      auth.uid(),
      v_fingerprint
    )
    on conflict (group_id, source_fingerprint)
      where source_fingerprint is not null and deleted_at is null
      do nothing
    returning id into v_expense_id;

    -- No row back means this fingerprint is already live in the group:
    -- somebody, possibly on another device, imported this transaction already.
    if v_expense_id is null then
      v_skipped := v_skipped || v_fingerprint;
      continue;
    end if;

    insert into expense_splits (expense_id, member_id, share_amount, share_percent)
    select v_expense_id,
           (s->>'member_id')::uuid,
           (s->>'share_amount')::numeric,
           nullif(s->>'share_percent', '')::numeric
    from   jsonb_array_elements(v_item->'splits') s;

    v_inserted := v_inserted + 1;
  end loop;

  return jsonb_build_object(
    'inserted',             v_inserted,
    'skipped',              coalesce(array_length(v_skipped, 1), 0),
    'skipped_fingerprints', to_jsonb(v_skipped)
  );
end;
$$;

grant execute on function import_expenses(uuid, jsonb) to authenticated;

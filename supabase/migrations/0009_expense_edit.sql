-- TALLY — edit + delete expenses
--
-- Both operations go through SECURITY DEFINER RPCs rather than direct table
-- writes. Two reasons:
--   1. Integrity. update_expense re-checks, server-side, that the splits sum to
--      the amount — the same invariant the UI enforces. If edits went through a
--      plain UPDATE policy, a client could PATCH `amount` via PostgREST without
--      touching the splits and desync the ledger. Funnelling every mutation
--      through the RPC makes that impossible.
--   2. Soft delete. A plain `update expenses set deleted_at = now()` is rejected
--      by RLS: the row's new state (deleted_at not null) fails the SELECT policy
--      (deleted_at is null), and Postgres won't let a member update a row into a
--      state they can no longer see. A SECURITY DEFINER function sidesteps that.
--
-- Authorization: TALLY is a shared ledger, so any *member* of the group can
-- edit or delete an expense, not just whoever created it. Both RPCs check
-- is_group_member(). The old creator-only update policy is therefore dropped.

drop policy if exists "creator soft-deletes expense" on expenses;

-- ---------------------------------------------------------------- edit
-- p_splits is a jsonb array of {member_id, share_amount, share_percent?}.
create or replace function update_expense(
  p_expense_id      uuid,
  p_payer_member_id uuid,
  p_amount          numeric,
  p_description     text,
  p_split_type      text,
  p_category_id     uuid,
  p_splits          jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_sum      numeric(12, 2);
begin
  -- Locate the (live) expense and authorize the caller.
  select group_id into v_group_id
  from   expenses
  where  id = p_expense_id and deleted_at is null;

  if v_group_id is null then
    raise exception 'Expense not found';
  end if;
  if not is_group_member(v_group_id) then
    raise exception 'Not authorized';
  end if;

  -- Guard: splits must add up to the total, same invariant the UI enforces.
  select coalesce(sum((s->>'share_amount')::numeric), 0)
  into   v_sum
  from   jsonb_array_elements(p_splits) s;

  if v_sum <> p_amount then
    raise exception 'Splits (%) must sum to amount (%)', v_sum, p_amount;
  end if;

  update expenses set
    payer_member_id = p_payer_member_id,
    amount          = p_amount,
    description     = p_description,
    split_type      = p_split_type,
    category_id     = p_category_id
  where id = p_expense_id;

  -- Replace the split set wholesale.
  delete from expense_splits where expense_id = p_expense_id;

  insert into expense_splits (expense_id, member_id, share_amount, share_percent)
  select p_expense_id,
         (s->>'member_id')::uuid,
         (s->>'share_amount')::numeric,
         nullif(s->>'share_percent', '')::numeric
  from   jsonb_array_elements(p_splits) s;
end;
$$;

-- ---------------------------------------------------------------- delete
-- Soft delete: the row stays for history but drops out of every read and the
-- balances view (all of which filter on deleted_at is null).
create or replace function delete_expense(p_expense_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
begin
  select group_id into v_group_id
  from   expenses
  where  id = p_expense_id and deleted_at is null;

  if v_group_id is null then
    raise exception 'Expense not found';
  end if;
  if not is_group_member(v_group_id) then
    raise exception 'Not authorized';
  end if;

  update expenses set deleted_at = now() where id = p_expense_id;
end;
$$;

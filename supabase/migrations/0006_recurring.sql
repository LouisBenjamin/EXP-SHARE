-- EXP-SHARE — Push 4: recurring expenses
--
-- A recurring_expenses row is a template; a daily tick materializes due
-- templates into real expenses (+ splits) and advances next_occurrence.

create table recurring_expenses (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references groups(id) on delete cascade,
  payer_member_id uuid not null references group_members(id),
  amount          numeric(12, 2) not null check (amount > 0),
  currency        char(3) not null default 'CAD',
  category_id     uuid references categories(id),
  description     text not null default '',
  split_type      text not null default 'equal'
                    check (split_type in ('equal', 'exact', 'percent')),
  frequency       text not null check (frequency in ('daily', 'weekly', 'monthly')),
  interval_count  int not null default 1 check (interval_count >= 1),
  next_occurrence date not null,
  active          boolean not null default true,
  created_by      uuid not null references profiles(id),
  created_at      timestamptz not null default now()
);

-- Snapshot of how each occurrence is split (mirrors expense_splits).
create table recurring_expense_splits (
  id            uuid primary key default gen_random_uuid(),
  recurring_id  uuid not null references recurring_expenses(id) on delete cascade,
  member_id     uuid not null references group_members(id),
  share_amount  numeric(12, 2) not null check (share_amount >= 0),
  share_percent numeric(5, 2),
  unique (recurring_id, member_id)
);

alter table recurring_expenses       enable row level security;
alter table recurring_expense_splits enable row level security;

-- recurring_expenses: members of the group manage them.
create policy "members read recurring" on recurring_expenses
  for select using (is_group_member(group_id));
create policy "members insert recurring" on recurring_expenses
  for insert with check (is_group_member(group_id) and created_by = auth.uid());
create policy "members update recurring" on recurring_expenses
  for update using (is_group_member(group_id));
create policy "members delete recurring" on recurring_expenses
  for delete using (is_group_member(group_id));

-- recurring_expense_splits: gated through the parent's group membership.
create policy "members read recurring splits" on recurring_expense_splits
  for select using (
    exists (select 1 from recurring_expenses r
            where r.id = recurring_id and is_group_member(r.group_id))
  );
create policy "members insert recurring splits" on recurring_expense_splits
  for insert with check (
    exists (select 1 from recurring_expenses r
            where r.id = recurring_id and is_group_member(r.group_id))
  );
create policy "members delete recurring splits" on recurring_expense_splits
  for delete using (
    exists (select 1 from recurring_expenses r
            where r.id = recurring_id and is_group_member(r.group_id))
  );

-- ============================================================
-- Tick: materialize every occurrence due on/before today, catching up if the
-- job missed days. SECURITY DEFINER so it runs without a user JWT (cron) and
-- bypasses RLS; it only uses values stored on the template. Returns the count
-- of expenses created.
-- ============================================================
create or replace function process_due_recurring()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r            recurring_expenses;
  new_id       uuid;
  step         interval;
  created      int := 0;
begin
  for r in
    select * from recurring_expenses where active and next_occurrence <= current_date
  loop
    step := r.interval_count * case r.frequency
      when 'daily'   then interval '1 day'
      when 'weekly'  then interval '1 week'
      when 'monthly' then interval '1 month'
    end;

    while r.next_occurrence <= current_date loop
      insert into expenses (group_id, payer_member_id, amount, currency,
                            category_id, description, split_type, occurred_on, created_by)
      values (r.group_id, r.payer_member_id, r.amount, r.currency,
              r.category_id, r.description, r.split_type, r.next_occurrence, r.created_by)
      returning id into new_id;

      insert into expense_splits (expense_id, member_id, share_amount, share_percent)
      select new_id, member_id, share_amount, share_percent
      from   recurring_expense_splits
      where  recurring_id = r.id;

      created := created + 1;
      r.next_occurrence := (r.next_occurrence + step)::date;
    end loop;

    update recurring_expenses set next_occurrence = r.next_occurrence where id = r.id;
  end loop;

  return created;
end;
$$;

-- Schedule a daily tick if pg_cron is available; otherwise leave a notice so it
-- can be scheduled (or invoked) manually. Guarded so the migration never fails
-- on projects where pg_cron isn't enabled.
do $$
begin
  perform cron.schedule('process-recurring-expenses', '0 6 * * *',
                        'select process_due_recurring();');
exception when others then
  raise notice 'pg_cron unavailable (%). Enable it and schedule process_due_recurring() manually.', sqlerrm;
end
$$;

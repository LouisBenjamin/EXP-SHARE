-- TALLY — Push 3: fix settlement signs in group_balances
--
-- net should be: paid - owed, adjusted by settlements. When a member RECEIVES a
-- settlement (to_member) they are owed less -> subtract it; when they PAY a
-- settlement (from_member) their debt shrinks -> add it. 0001 had these two
-- flipped, so recording a settlement pushed balances further apart instead of
-- toward zero. Recreate the view with the correct signs.
--
-- Convention: net > 0  => the member is owed money (others owe them)
--             net < 0  => the member owes money
create or replace view group_balances with (security_invoker = true) as
with paid as (
  select e.group_id, e.payer_member_id as member_id, sum(e.amount) as total_paid
  from   expenses e
  where  e.deleted_at is null
  group  by e.group_id, e.payer_member_id
),
owed as (
  select e.group_id, es.member_id, sum(es.share_amount) as total_owed
  from   expense_splits es
  join   expenses e on es.expense_id = e.id
  where  e.deleted_at is null
  group  by e.group_id, es.member_id
),
settled_out as (
  select group_id, from_member as member_id, sum(amount) as amount
  from   settlements
  group  by group_id, from_member
),
settled_in as (
  select group_id, to_member as member_id, sum(amount) as amount
  from   settlements
  group  by group_id, to_member
),
all_members as (
  select distinct group_id, id as member_id from group_members
)
select
  am.group_id,
  am.member_id,
  coalesce(p.total_paid,    0)
  - coalesce(o.total_owed,  0)
  - coalesce(si.amount,     0)   -- received a settlement -> owed less
  + coalesce(so_.amount,    0)   -- paid a settlement     -> owe less
  as net
from       all_members am
left join  paid        p   on p.group_id   = am.group_id and p.member_id   = am.member_id
left join  owed        o   on o.group_id   = am.group_id and o.member_id   = am.member_id
left join  settled_out so_ on so_.group_id = am.group_id and so_.member_id = am.member_id
left join  settled_in  si  on si.group_id  = am.group_id and si.member_id  = am.member_id;

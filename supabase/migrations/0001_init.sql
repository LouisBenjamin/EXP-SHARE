-- EXP-SHARE — initial schema
-- Run this in the Supabase SQL Editor (or via `supabase db push`)

create extension if not exists "pgcrypto";

-- ============================================================
-- TABLES
-- ============================================================

-- Mirrors auth.users; auto-populated via trigger below
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at  timestamptz not null default now()
);

create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name',
             split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

create table groups (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  -- 6-char uppercase join code, derived from a random UUID
  join_code text not null unique default upper(substring(gen_random_uuid()::text, 1, 6)),
  created_by uuid not null references profiles(id),
  created_at  timestamptz not null default now()
);

-- group_members: user_id is nullable to support guests (Push 2)
-- Everything else (expenses, splits, settlements) FKs to this table's PK,
-- not directly to profiles, so guests and real users are interchangeable.
create table group_members (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references groups(id) on delete cascade,
  user_id      uuid references profiles(id) on delete cascade, -- null = guest
  display_name text,                                           -- required if user_id null
  role         text not null default 'member',
  joined_at    timestamptz not null default now(),
  constraint chk_member_identity check (
    user_id is not null or (display_name is not null and display_name <> '')
  ),
  unique (group_id, user_id) -- prevents duplicate real users; multiple nulls allowed
);

-- null group_id = global default; group-scoped categories override per group
create table categories (
  id       uuid primary key default gen_random_uuid(),
  group_id uuid references groups(id) on delete cascade,
  name     text not null,
  icon     text not null default 'label'
);

create table expenses (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references groups(id) on delete cascade,
  payer_member_id uuid not null references group_members(id),
  amount          numeric(12, 2) not null check (amount > 0),
  currency        char(3) not null default 'CAD',
  category_id     uuid references categories(id),
  description     text not null default '',
  occurred_on     date not null default current_date,
  split_type      text not null default 'equal'
                    check (split_type in ('equal', 'exact', 'percent')),
  created_by      uuid not null references profiles(id),
  created_at      timestamptz not null default now(),
  deleted_at      timestamptz -- soft delete
);

create table expense_splits (
  id            uuid primary key default gen_random_uuid(),
  expense_id    uuid not null references expenses(id) on delete cascade,
  member_id     uuid not null references group_members(id),
  share_amount  numeric(12, 2) not null check (share_amount >= 0),
  share_percent numeric(5, 2),
  unique (expense_id, member_id)
);

create table settlements (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  from_member uuid not null references group_members(id),
  to_member   uuid not null references group_members(id),
  amount      numeric(12, 2) not null check (amount > 0),
  currency    char(3) not null default 'CAD',
  occurred_on date not null default current_date,
  note        text not null default '',
  created_at  timestamptz not null default now(),
  check (from_member <> to_member)
);

-- ============================================================
-- BALANCES VIEW
-- security_invoker = true ensures the caller's RLS applies,
-- so users only see their own groups even though this is a view.
-- ============================================================
create view group_balances with (security_invoker = true) as
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
  + coalesce(si.amount,     0)
  - coalesce(so_.amount,    0) as net
from       all_members am
left join  paid        p   on p.group_id   = am.group_id and p.member_id   = am.member_id
left join  owed        o   on o.group_id   = am.group_id and o.member_id   = am.member_id
left join  settled_out so_ on so_.group_id = am.group_id and so_.member_id = am.member_id
left join  settled_in  si  on si.group_id  = am.group_id and si.member_id  = am.member_id;

-- ============================================================
-- ROW LEVEL SECURITY
-- Every table is locked down. The helper function below is
-- marked SECURITY DEFINER so it can read group_members without
-- causing infinite RLS recursion.
-- ============================================================

alter table profiles       enable row level security;
alter table groups         enable row level security;
alter table group_members  enable row level security;
alter table categories     enable row level security;
alter table expenses       enable row level security;
alter table expense_splits enable row level security;
alter table settlements    enable row level security;

-- Used by all RLS policies; SECURITY DEFINER bypasses RLS on group_members
-- for this specific lookup, avoiding infinite recursion.
create or replace function is_group_member(gid uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

-- profiles
create policy "read own profile" on profiles
  for select using (id = auth.uid());

create policy "read co-member profiles" on profiles
  for select using (
    exists (
      select 1 from group_members gm1
      join   group_members gm2 on gm1.group_id = gm2.group_id
      where  gm1.user_id = auth.uid() and gm2.user_id = profiles.id
    )
  );

create policy "update own profile" on profiles
  for update using (id = auth.uid());

-- groups
create policy "members read group" on groups
  for select using (is_group_member(id));

create policy "authed users create group" on groups
  for insert with check (auth.uid() is not null and created_by = auth.uid());

create policy "owner updates group" on groups
  for update using (created_by = auth.uid());

-- group_members
create policy "members read roster" on group_members
  for select using (is_group_member(group_id));

-- The creator can add themselves as the first member; join-code and guest RPCs
-- handle all other insertions (added in 0002_rpcs.sql).
create policy "creator adds initial member" on group_members
  for insert with check (
    exists (select 1 from groups where id = group_id and created_by = auth.uid())
  );

-- categories
create policy "read global or group categories" on categories
  for select using (group_id is null or is_group_member(group_id));

create policy "members manage group categories" on categories
  for all using (is_group_member(group_id))
  with check (is_group_member(group_id));

-- expenses
create policy "members read expenses" on expenses
  for select using (is_group_member(group_id) and deleted_at is null);

create policy "members insert expense" on expenses
  for insert with check (is_group_member(group_id) and created_by = auth.uid());

create policy "creator soft-deletes expense" on expenses
  for update using (created_by = auth.uid());

-- expense_splits
create policy "members read splits" on expense_splits
  for select using (
    exists (
      select 1 from expenses e
      where e.id = expense_id and is_group_member(e.group_id)
    )
  );

create policy "members insert splits" on expense_splits
  for insert with check (
    exists (
      select 1 from expenses e
      where e.id = expense_id and is_group_member(e.group_id)
    )
  );

-- settlements
create policy "members read settlements" on settlements
  for select using (is_group_member(group_id));

create policy "members insert settlement" on settlements
  for insert with check (is_group_member(group_id));

-- ============================================================
-- SEED: default categories (global, group_id = null)
-- ============================================================
insert into categories (group_id, name, icon) values
  (null, 'Food & Drink',   'restaurant'),
  (null, 'Groceries',      'shopping_cart'),
  (null, 'Housing',        'home'),
  (null, 'Transportation', 'directions_car'),
  (null, 'Entertainment',  'movie'),
  (null, 'Health',         'favorite'),
  (null, 'Travel',         'flight'),
  (null, 'Shopping',       'shopping_bag'),
  (null, 'Utilities',      'bolt'),
  (null, 'Other',          'more_horiz');

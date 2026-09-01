-- EXP-SHARE — fix broken handle_new_user trigger
--
-- The 0001 version was `security definer` without a search_path, so when the
-- trigger fired from the auth role it couldn't resolve `profiles`, failing every
-- signup with "Database error saving new user". This recreates it with an
-- explicit search_path + schema-qualified table, and backfills any users that
-- were created before the trigger worked (or before it existed).

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name',
             split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Backfill profiles for any pre-existing auth users (e.g. accounts created
-- before the migration, which never got a profiles row).
insert into public.profiles (id, display_name)
select id, coalesce(raw_user_meta_data->>'display_name', split_part(email, '@', 1))
from auth.users
on conflict (id) do nothing;

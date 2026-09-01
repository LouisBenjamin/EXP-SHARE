-- TALLY — Push 2: member management RPCs
--
-- 0001's group_members RLS only lets a creator add their own initial row. Adding
-- more real members (join by code) or guests needs SECURITY DEFINER functions
-- that enforce their own checks and bypass that narrow insert policy.

-- Join the group whose join_code matches; adds the caller as a 'member'.
-- Idempotent: re-joining is a no-op. Returns the joined group.
create or replace function join_group_by_code(p_code text)
returns groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g groups;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  select * into g from groups where join_code = upper(trim(p_code));
  if not found then
    raise exception 'No group found for code %', p_code using errcode = 'no_data_found';
  end if;

  insert into group_members (group_id, user_id, role)
  values (g.id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return g;
end;
$$;

-- Add a guest (account-less participant) to a group the caller belongs to.
-- Returns the new group_members row.
create or replace function add_guest_member(p_group_id uuid, p_name text)
returns group_members
language plpgsql
security definer
set search_path = public
as $$
declare
  m group_members;
begin
  if not is_group_member(p_group_id) then
    raise exception 'Not a member of this group' using errcode = '42501';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Guest name is required' using errcode = '22023';
  end if;

  insert into group_members (group_id, user_id, display_name, role)
  values (p_group_id, null, trim(p_name), 'member')
  returning * into m;

  return m;
end;
$$;

grant execute on function join_group_by_code(text)          to authenticated;
grant execute on function add_guest_member(uuid, text)      to authenticated;

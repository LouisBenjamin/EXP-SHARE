-- TALLY — group photos + per-user group summaries
--
-- (1) groups.photo_url: set via a SECURITY DEFINER RPC so ANY member (not
--     just the owner) can set the group photo, without widening the general
--     "owner updates group" policy that still gates name/join_code changes.
-- (2) group-photos storage bucket: public read (group photos aren't
--     sensitive), write restricted to members of the group the path names.
--     Path convention: {group_id}/{filename}.
-- (3) my_group_summaries view: one row per group the caller belongs to,
--     with their own net balance attached, so the groups list can show a
--     "you owe / you're owed" status line without an N+1 balances fetch.

alter table groups add column photo_url text;

create or replace function update_group_photo(p_group_id uuid, p_photo_url text)
returns groups
language plpgsql
security definer
set search_path = public
as $$
declare
  g groups;
begin
  if not is_group_member(p_group_id) then
    raise exception 'not a member of this group';
  end if;

  update groups set photo_url = p_photo_url where id = p_group_id
  returning * into g;

  return g;
end;
$$;

insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', true)
on conflict (id) do nothing;

create policy "public read group photos" on storage.objects
  for select using (bucket_id = 'group-photos');

create policy "members upload group photo" on storage.objects
  for insert with check (
    bucket_id = 'group-photos'
    and is_group_member((storage.foldername(name))[1]::uuid)
  );

create policy "members replace group photo" on storage.objects
  for update using (
    bucket_id = 'group-photos'
    and is_group_member((storage.foldername(name))[1]::uuid)
  );

create policy "members delete group photo" on storage.objects
  for delete using (
    bucket_id = 'group-photos'
    and is_group_member((storage.foldername(name))[1]::uuid)
  );

create or replace view my_group_summaries with (security_invoker = true) as
select
  g.id,
  g.name,
  g.join_code,
  g.photo_url,
  gm.id           as my_member_id,
  coalesce(gb.net, 0) as my_net
from       groups        g
join       group_members gm on gm.group_id = g.id and gm.user_id = auth.uid()
left join  group_balances gb on gb.group_id = g.id and gb.member_id = gm.id
order by   g.created_at desc;

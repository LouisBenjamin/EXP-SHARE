-- TALLY — Push 5: device tokens for push notifications (groundwork).
--
-- Stores each user's push registration token(s). Provider-agnostic: the token is
-- an FCM registration token today, but the schema doesn't assume FCM. The app
-- upserts a row on launch once notifications are wired; a send-push Edge Function
-- reads these to deliver notifications. See docs/push-notifications.md.
create table device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('android', 'web', 'ios')),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table device_tokens enable row level security;

-- A user manages only their own tokens.
create policy "manage own device tokens" on device_tokens
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

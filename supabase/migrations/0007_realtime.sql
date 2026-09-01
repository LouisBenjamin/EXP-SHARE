-- TALLY — Push 5: enable Realtime on the tables the app watches.
--
-- Adds tables to the supabase_realtime publication so Postgres change events are
-- streamed to subscribed clients. RLS still applies to what each client sees, and
-- the app only uses events as a signal to re-fetch (RLS-scoped), so no sensitive
-- data leaks through the stream. Guarded so re-running is safe.
do $$
declare
  t text;
begin
  foreach t in array array['expenses', 'expense_splits', 'settlements', 'group_members']
  loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception
      when duplicate_object then null; -- already published
      when undefined_object then
        raise notice 'publication supabase_realtime missing; enable Realtime in the dashboard';
    end;
  end loop;
end
$$;

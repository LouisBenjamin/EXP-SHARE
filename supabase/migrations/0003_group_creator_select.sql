-- EXP-SHARE — let a group creator read groups they own.
--
-- createGroup() does `insert ... returning` (Supabase .insert().select()).
-- Postgres runs the SELECT policy against the RETURNING row, but at that moment
-- the creator has no group_members row yet (it's inserted on the next call), so
-- the members-only read policy (is_group_member) hides the row and the whole
-- statement fails with "new row violates row-level security policy".
--
-- Allowing creators to read their own groups makes the RETURNING row visible and
-- is correct regardless: a creator should always be able to see their group.
create policy "creator reads group" on groups
  for select using (created_by = auth.uid());

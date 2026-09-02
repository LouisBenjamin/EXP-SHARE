-- TALLY — deletable categories, take two
--
-- 0012 switched the category foreign keys to ON DELETE SET NULL so a category
-- still referenced by an expense could be removed without orphaning rows. That
-- fixes the database, but the client still deletes categories with a plain
--   delete from categories where id = ?
-- and that has two failure modes the user sees as "can't delete categories":
--
--   1. It silently deletes zero rows whenever RLS hides the target — a global
--      default (group_id is null), or a category owned by another group. No
--      error comes back, the list refetches, the category is still there.
--   2. Where the SET NULL cascade from 0012 isn't in place (an environment
--      still on <= 0011), the delete fails outright with a foreign-key
--      violation from expenses / recurring_expenses / merchant_rules.
--
-- Route deletion through a SECURITY DEFINER RPC instead — the same pattern
-- delete_expense, update_expense and update_group_photo already use. It
-- authorizes the caller as a member of the category's group, raises a clear
-- error for the cases that should fail, detaches every reference explicitly
-- (so it works regardless of the FK action), then deletes.

create or replace function delete_category(p_category_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
begin
  select group_id into v_group_id
  from   categories
  where  id = p_category_id;

  if not found then
    raise exception 'Category not found';
  end if;
  -- Global defaults belong to every group; a single group can't delete them.
  if v_group_id is null then
    raise exception 'Default categories cannot be deleted';
  end if;
  if not is_group_member(v_group_id) then
    raise exception 'Not authorized';
  end if;

  -- Detach references explicitly so the delete succeeds even where the
  -- ON DELETE SET NULL cascade from 0012 never ran. Only this group's own
  -- rows can point at the category, and SECURITY DEFINER clears RLS.
  update expenses          set category_id = null where category_id = p_category_id;
  update recurring_expenses set category_id = null where category_id = p_category_id;
  update merchant_rules     set category_id = null where category_id = p_category_id;

  delete from categories where id = p_category_id;
end;
$$;

-- TALLY — category management
--
-- Categories have existed since 0001 (a nullable group_id means "global
-- default"), and every expense/recurring template/merchant rule already
-- carries a category_id. What's missing is the app being able to touch them:
-- there was no delete-safe path for a category still in use, and nothing
-- stopped a group from creating two categories with the same name.
--
-- This migration also re-seeds the 10 global categories with Phosphor icon
-- slugs (lib/core/icons.dart) — Tally's icon set moved off Material.

-- ---- deletable categories --------------------------------------------

-- Each FK was declared with no ON DELETE action (the implicit NO ACTION),
-- so deleting a category still referenced by a row fails outright. Since a
-- category can now be deleted from the UI, an expense/template/rule that
-- pointed at it should simply fall back to "uncategorized" rather than block
-- the delete or cascade into losing data.
alter table expenses
  drop constraint expenses_category_id_fkey,
  add constraint expenses_category_id_fkey
    foreign key (category_id) references categories(id) on delete set null;

alter table recurring_expenses
  drop constraint recurring_expenses_category_id_fkey,
  add constraint recurring_expenses_category_id_fkey
    foreign key (category_id) references categories(id) on delete set null;

alter table merchant_rules
  drop constraint merchant_rules_category_id_fkey,
  add constraint merchant_rules_category_id_fkey
    foreign key (category_id) references categories(id) on delete set null;

-- ---- no duplicate names within a group ---------------------------------

-- Global rows (group_id is null) are exempt — case-insensitive uniqueness
-- there is a seed-data concern, not something a group can trigger.
create unique index categories_group_name_idx
  on categories (group_id, lower(name))
  where group_id is not null;

-- ---- re-seed global categories with Phosphor slugs ---------------------

alter table categories alter column icon set default 'tag';

update categories set icon = case icon
  when 'restaurant'      then 'fork-knife'
  when 'shopping_cart'   then 'shopping-cart'
  when 'home'            then 'house'
  when 'directions_car'  then 'car'
  when 'movie'           then 'film-slate'
  when 'favorite'        then 'heartbeat'
  when 'flight'          then 'airplane-tilt'
  when 'shopping_bag'    then 'shopping-bag-open'
  when 'bolt'            then 'lightning'
  when 'more_horiz'      then 'dots-three-outline'
  when 'label'           then 'tag'
  else icon
end
where group_id is null;

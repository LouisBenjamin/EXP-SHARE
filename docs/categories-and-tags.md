# Categories & tags

Every expense can carry one category (an icon + a name — Food & Drink,
Rent, Coffee…), and a group can teach the app to fill that category in
automatically by keyword. Both are managed from the **Labels** tab on the
group screen, next to Expenses / Balances / Members.

## Data model

`categories` (`supabase/migrations/0001_init.sql`, extended by `0012_categories.sql`):

| column | notes |
|---|---|
| `id` | uuid PK |
| `group_id` | **nullable** — null means a global default, seeded once and shared by every group |
| `name` | unique per group, case-insensitively (global rows are exempt) |
| `icon` | a slug into `kCategoryIcons` (`lib/core/icons.dart`), e.g. `'fork-knife'` |

`expenses.category_id`, `recurring_expenses.category_id`, and
`merchant_rules.category_id` all FK to it with `on delete set null` — deleting
a category never blocks or cascades, the rows that pointed at it just become
uncategorized.

RLS: `"members manage group categories"` (`for all`) lets a member
insert/update/delete rows scoped to their own group; a null `group_id` makes
`is_group_member(group_id)` evaluate to null (not true), so global defaults
are correctly read-only from the client. `CategoriesRepository`
(`lib/features/expenses/data/categories_repository.dart`) only ever writes
with an explicit `group_id` for this reason — there's no path to insert a
global row from the app.

## Tags are `merchant_rules`, not a separate table

A tag — *"COSTCO always means Groceries"* — is the exact shape the statement
importer already needed: a keyword, a match type (`contains` / `prefix` /
`exact`), a category, and a `share`/`skip` action. Rather than build a second
keyword→category table, tags **are** `merchant_rules` rows
(`supabase/migrations/0011_import.sql`); the Labels tab is a second UI over
the same data statement import has always used, and the two features have
been consistent by construction since the first migration. See
[`statement-import.md`](statement-import.md) for the matching rules
(`lib/features/import/logic/merchant_rules.dart`) and the case for keeping
regex out of it.

A tag now applies in two places:

- **Import review** — `matchMerchantRule`, unchanged: merchant name first,
  then the statement's own category description as a weaker fallback.
- **The Add-expense form** — `matchTagCategory`, which runs the same
  precedence (priority ascending, then longer pattern) against the typed
  description as you type. It never fires once you've picked a category by
  hand (`add_expense_screen.dart`'s `_categoryTouched` flag), and a
  skip-action tag is ignored — "never offer during import" has no meaning for
  a manual expense.

## Icons

`lib/core/icons.dart` is the app's one icon vocabulary, drawn from
[Phosphor](https://phosphoricons.com) (MIT) via `phosphor_flutter`:

- `kCategoryIcons` — the curated slug → `IconData` map the category picker
  offers. Add to it (never remove a key a stored row might reference) when a
  new use case needs an icon the picker doesn't have yet.
- `iconForCategory(slug)` — resolves a category's stored `icon` slug,
  including the pre-migration Material names (`'restaurant'`, `'home'`, …)
  via `_legacyIconAliases`, so a row written before `0012_categories.sql`
  still renders instead of falling back to the generic tag icon.
- `categoryTint(id, brightness)` / `onCategoryTint(tint)` — a deterministic
  HSL tint derived from the category's id, so every category avatar gets a
  distinct, theme-appropriate colour with no colour picker or `color` column.
- `AppIcons` — semantic constants for app chrome (add, edit, delete, …), so
  the rest of the app never reaches for `PhosphorIconsRegular.*` or
  `Icons.*` directly.

Always use the static-const accessors (`PhosphorIconsRegular.house`), never
the `PhosphorIcons.regular.house` getter form — only the const form survives
`flutter build --tree-shake-icons`.

## Files

```
lib/core/icons.dart                          icon vocabulary, tints
lib/features/expenses/data/categories_repository.dart   category CRUD
lib/features/expenses/providers/categories_provider.dart
lib/features/import/logic/merchant_rules.dart matchMerchantRule, matchTagCategory
lib/features/import/data/merchant_rules_repository.dart tag CRUD
lib/features/labels/ui/
  labels_tab.dart       the two sections, embedded as the group's 4th tab
  labels_screen.dart     standalone route (old /import/rules redirects here)
  category_dialog.dart   name + icon picker
  tag_dialog.dart         keyword + category, match type behind "Advanced"
supabase/migrations/0012_categories.sql
test/features/import/merchant_rules_test.dart   matchMerchantRule, matchTagCategory
test/features/labels/labels_tab_test.dart
```

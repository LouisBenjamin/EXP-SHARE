# Tally

Tally is a free, cross-platform expense splitter built with Flutter and Supabase. It covers what Splitwise covers, shared groups, itemised expenses, who-owes-whom balances and settle up, plus recurring expenses and bank-statement import, with no subscription, no ads, and a database you own outright.

One codebase ships to the web and to Android. This is a portfolio project, so the README goes further than usual into *why* things are built the way they are.

---

## What works today

### Accounts and sign-in

Passwordless email one-time codes. You enter an email, Supabase mails a code, you type it back (`signInWithOtp`, then `verifyOTP`). No passwords are stored, so there is no reset flow to build and no OAuth provider to configure.

A `profiles` row is created automatically by a Postgres trigger on `auth.users`, seeded with the display name from user metadata and falling back to the local part of the email address.

### Groups

* Create a group and the creator is written in as the first member with role `owner`.
* Every group gets a six-character uppercase `join_code`, generated in the database rather than in the client.
* Two ways to join: type the code, or open the deep link `/join?code=XXXXXX`, which joins and drops you straight into the group.
* Group photos upload to a Supabase Storage bucket from both web and Android. The storage path is stable per group, so the public URL gets a cache-busting timestamp appended on write.
* **Guests**: participants who have no account at all. Add one by name and they can pay for an expense and be split into one exactly like a signed-up user.

### Expenses

* Amount, description, payer, category, and a per-member split.
* Three split modes: **equal**, **exact amounts**, and **percentages**. The form validates continuously and refuses to save until the parts reconcile against the total.
* Full edit and delete. Delete is a soft delete: the row keeps its history but disappears from every read and from the balances view.
* Ten seeded global categories, plus per-group categories.

### Balances and settling up

* A `group_balances` SQL view computes each member's net position: total paid, minus total owed, plus settlements received, minus settlements sent.
* The Balances tab runs a greedy debt simplification, repeatedly matching the largest debtor against the largest creditor. A five-person group therefore sees at most four suggested payments instead of everyone paying everyone.
* Recording a payment writes a `settlements` row, which feeds back through the same view on the next read.

### Recurring expenses

* Templates carry a frequency (daily, weekly, monthly) and an interval count, so "every 2 weeks" is one row.
* `process_due_recurring()` materialises **every** occurrence due on or before today, not just the next one, so a cron run that gets missed catches up instead of silently skipping a month.
* Scheduled through pg_cron at 06:00 daily. The migration wraps the schedule call so a project without pg_cron enabled gets a notice instead of a failed migration.

### Insights

Monthly spend per category for a group, sorted from largest to smallest.

### Importing a bank statement

Built for the case where roommates share one card and want to peel the shared transactions off it each month, without hand-typing forty rows.

* Pick a bank CSV, review the transactions on screen, tick the shared ones, choose how they split, and promote them into real group expenses in a single batch.
* **Merchant rules** are group-scoped, not per device. A rule matches a merchant name fragment as a substring (`COSTCO WHOLESALE W515` and `W521` are the same warehouse) and decides two things: which category the transaction gets tagged with, and whether it is offered for sharing at all. An `action = 'skip'` rule means "my hobby shop is never a shared expense" for the whole group at once.
* **Cross-device deduplication.** Two roommates importing overlapping copies of the same statement from two phones is the normal case, not an error. Each promoted expense stores an opaque `source_fingerprint`; before review the app fetches the group's existing fingerprints and marks rows that are already in as *Already imported*, with the checkbox disabled. A partial unique index backstops the race where both devices commit at the same moment.
* Split maths reuses `computeSplits()`, the same function the expense forms use, so an equal or percentage split means exactly one thing across the whole app.
* Nothing throws. Every parser returns a result object with a `valid` flag and a readable status, so one malformed row costs one row instead of the whole file.

The privacy design is covered under [Architecture](#decision-statement-import-keeps-raw-data-off-the-server) below and in full in [`docs/statement-import.md`](docs/statement-import.md).

### Live updates

The group screen subscribes to Postgres change events on `expenses`, `expense_splits`, `settlements` and `group_members`. Any event invalidates the matching Riverpod providers, so the Expenses, Balances and Members tabs all refresh when anyone in the group makes a change. The subscription auto-disposes, and the channel unsubscribes, the moment you leave the group screen.

Events are used purely as a trigger to re-fetch. The refetch goes through the normal RLS-scoped queries, so the realtime path never becomes a way to see data you are not entitled to.

### Desktop layout

Content is centered and capped at 1100px while the app chrome stays full-bleed, so a row's amount never drifts a monitor's width away from its label. There is no breakpoint involved: on a phone the window is already narrower than the cap, so the same widget is a no-op and mobile renders unchanged.

---

## Architecture

### Layers

Every feature folder follows the same four-layer shape:

```
lib/features/<feature>/
  ui/         Screens and widgets. Never imports the Supabase client.
  providers/  Riverpod providers. Async state, caching, invalidation.
  data/       Repository. The only place allowed to talk to Supabase.
  logic/      Pure Dart. No Flutter, no IO, trivially unit-testable.
```

The rules are worth stating because they are what keeps the test suite cheap:

1. UI never touches the network directly, it watches a provider.
2. Repositories never import Flutter, they map rows to models and back.
3. Money and settlement rules live in `logic/` (or `core/money.dart`) as pure functions, which is why they can be tested without a widget tree or a database.

### Why Riverpod

Compile-time-safe dependency injection with no `BuildContext` needed to read state. Three of its features are load-bearing here:

* `family` providers keyed by group id, so per-group data is cached independently.
* `autoDispose` for anything scoped to a screen, which is what makes the realtime channel tear itself down correctly.
* `ref.invalidate` callable from anywhere, which is exactly the primitive the realtime listener needs.

The non-codegen flavour is used deliberately. Adding `riverpod_annotation` and `build_runner` would buy a little less boilerplate at the cost of a codegen step in CI and in every clone of the repo.

### Why go_router

The web build makes URLs part of the product. `/groups/<id>/expenses/<id>/edit` and `/join?code=ABC123` are real, shareable, bookmarkable addresses, and the browser back button has to behave. go_router gives declarative nested routes and a single `redirect` guard that answers the whole auth question in five lines. A small `ChangeNotifier` bridges Supabase's `onAuthStateChange` stream into the `refreshListenable` go_router expects, so signing in or out re-evaluates the guard immediately. Nothing in the app calls `Navigator.push` after login; the redirect handles it.

### Why Supabase, and no backend of my own

Postgres with Row Level Security puts the authorisation model in the database, next to the data it protects, instead of in a hand-written API layer that has to be audited endpoint by endpoint. There is no bespoke server in this project. The Flutter client speaks to Postgres through PostgREST, and anything RLS cannot express becomes a `SECURITY DEFINER` function.

The trade-off is real and worth naming: business rules end up written in SQL, which is harder to unit test than Dart and needs a migration to change. So the split is deliberate. Rules that are *about money maths* stayed in Dart, where they are covered by fast tests. Rules that are *about who may see what* stayed in SQL, where a client that skips the app cannot bypass them.

---

## Data model

| Table | Purpose |
|---|---|
| `profiles` | Mirrors `auth.users`, auto-populated by trigger. |
| `groups` | Name, join code, photo URL, creator. |
| `group_members` | One row per participant in a group. `user_id` is nullable. |
| `categories` | Global rows (`group_id is null`) plus per-group ones. |
| `expenses` | Amount, payer, category, split type, `occurred_on`, `deleted_at`, and `source_fingerprint` for imported rows. |
| `expense_splits` | One row per participant per expense, with amount and optional percent. |
| `settlements` | A payment from one member to another. |
| `recurring_expenses` / `recurring_expense_splits` | Templates and their split shape. |
| `merchant_rules` | Group-scoped statement-import presets: a merchant name pattern, a category, and share or skip. Names only, no amounts or references. |
| `device_tokens` | Push tokens, groundwork for FCM. |

### Decision: everything points at `group_members`, not `profiles`

`expenses.payer_member_id`, `expense_splits.member_id` and both settlement columns all reference `group_members.id`, a surrogate key, rather than referencing a user directly.

This is the one decision the rest of the schema hangs off. Because `group_members.user_id` is nullable, a guest with no account is just a member row with a `display_name` and a null `user_id`, and a check constraint enforces that one of the two is always present. Guests are therefore first-class in every query, every view and every balance calculation, with no `if (isGuest)` branch anywhere in the codebase. A `unique (group_id, user_id)` constraint still prevents a real user joining twice while allowing many guests, since Postgres treats nulls as distinct in unique indexes.

### Decision: RLS is the security boundary

Every table has RLS enabled. Policies are written against one helper:

```sql
create or replace function is_group_member(gid uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;
```

It is `SECURITY DEFINER` on purpose. A policy on `group_members` that itself queries `group_members` recurses infinitely; running the lookup as the definer bypasses RLS for that one narrow question and breaks the cycle.

### Decision: RPCs exactly where RLS is deliberately too narrow

The insert policy on `group_members` only lets a group's creator add their own first row. That is intentionally restrictive, because a policy permissive enough to cover joining by code would also be permissive enough to add yourself to any group you can name. The remaining paths are `SECURITY DEFINER` functions that enforce their own checks instead:

* `join_group_by_code(code)` looks the group up by code and inserts the caller. Idempotent, so re-joining is a no-op.
* `add_guest_member(group_id, name)` verifies the caller's membership before inserting a guest.
* `update_expense(...)` rewrites an expense and its splits in one transaction, re-checking membership and re-verifying that the splits sum to the amount **server-side**, so client validation is a convenience rather than the enforcement point.
* `delete_expense(id)` performs the soft delete. A plain `update` that sets `deleted_at` is rejected, because the resulting row no longer satisfies the `deleted_at is null` select policy.
* `update_group_photo(group_id, url)` writes the photo URL after the storage upload.
* `import_expenses(group_id, items)` promotes reviewed statement rows into expenses and splits in one transaction, re-checks the splits-sum-to-amount invariant per row, and returns `{ inserted, skipped, skipped_fingerprints }` so a row someone else already imported is reported rather than raised as an error.

### Decision: views for read shapes, with `security_invoker = true`

* `group_balances` computes net position per member from paid, owed and settled totals.
* `my_group_summaries` returns the caller's groups with their own net balance already attached, which is what lets the groups list render a "you owe / you are owed" line per card without an N+1 balance fetch per group.

Both are declared `with (security_invoker = true)` so the caller's RLS applies to the underlying tables. Without it a view runs as its owner and quietly becomes a hole straight through the policy set.

### Decision: soft delete

`expenses.deleted_at` is a timestamp rather than a real `delete`. Reads, the balances view and the insights query all filter on `deleted_at is null`. History survives, and a deleted expense stops affecting anyone's balance the moment it is removed.

### Decision: statement import keeps raw data off the server

Raw statement data never reaches Postgres. The CSV is parsed on the device and held in screen state for the review session only. It is never uploaded and never written to disk, and closing the screen discards it. Exactly two things cross the wire:

* `merchant_rules` rows, which hold merchant name patterns only: no amounts, dates, reference numbers or card numbers.
* `expenses.source_fingerprint`, which is `SHA-256(group_id + ':' + normalized_reference_number)`, computed on the client.

The fingerprint is deliberately hashed client-side. Doing it in Postgres would mean sending the bank reference number to the server, which is the exact thing the design avoids, so the server cannot verify the digest and simply trusts it. That is an acceptable trade: the input is a roughly 23-character reference number rather than a low-entropy merchant name, so the hash is not brute-forceable; the group id is mixed in, so the same transaction produces different digests in different groups and cannot be correlated across them; and the worst a forged digest can do is block a transaction in a group the caller already belongs to and could have imported and deleted anyway.

The unique index on `(group_id, source_fingerprint)` is partial on two conditions, `source_fingerprint is not null and deleted_at is null`. The first leaves hand-entered expenses unconstrained. The second means deleting an imported expense makes it importable again, rather than leaving a soft-deleted row that blocks its own transaction forever with no visible expense to explain why. The `on conflict` clause in `import_expenses()` repeats that predicate verbatim, because Postgres will not use a partial unique index as a conflict arbiter otherwise, and the mismatch fails at runtime rather than at migration time.

`normalizeReference()` is pinned by known vectors in `test/features/import/fingerprint_test.dart`. Changing it would invalidate every fingerprint already stored, so if those tests fail, that is the signal to stop.

### Migrations are the source of truth

`supabase/migrations/` is numbered and forward-only. Later files carry fixes along with their reasons, which doubles as a record of what went wrong: `0002` adds the explicit `search_path` that stops the new-user trigger failing with "Database error saving new user", `0003` adds the creator select policy that `createGroup()`'s `insert ... returning` needs (at that instant the creator has no `group_members` row yet, so `is_group_member` would hide the row it just wrote), `0005` corrects the balances view.

---

## Money handling

`double` is never used for a currency amount, anywhere.

* **In Postgres**: `numeric(12,2)`, with check constraints keeping amounts positive and shares non-negative.
* **In Dart**: `package:decimal`. Conversion happens once, at the boundary, in `toDecimal()`.
* **Over the wire**: amounts are sent as strings, so `numeric(12,2)` precision survives the JSON round trip instead of being downgraded to an IEEE 754 double in transit.

Rounding is defined rather than incidental, because a split that fails to sum to its total is a bug users notice immediately:

* **Equal splits** compute the per-head share at two decimal places, then hand the entire remainder to the first participant. Splitting $10.00 three ways produces 3.34 / 3.33 / 3.33, not three shares of 3.33 and a lost cent.
* **Percentage splits** round each share half-up to whole cents, then give the last participant `amount - assigned`, absorbing the drift so the parts always reconcile exactly.
* **Exact splits** are never adjusted, only validated. The form reports "Assigned $X of $Y" until the sum matches, and enables save only then.

The split maths lives in one pure function, `computeSplits()`, shared by the one-off expense form, the recurring template form and the statement-import plan, so the three can never drift apart. (Import allows equal and percentage splits only: an exact split is defined against one total and cannot be applied across rows with different totals.)

## Debt simplification

`simplifyDebts()` takes net balances and returns a list of suggested payments. It sorts creditors and debtors by size, then repeatedly settles the largest against the largest, which yields at most `n - 1` transfers for `n` members. The alternative, showing every pairwise debt, produces up to `n * (n - 1) / 2` rows and is unreadable past about four people.

---

## Project structure

```
lib/
  main.dart               Bootstrap: init Supabase, then runApp
  app.dart                MaterialApp.router, light and dark themes
  core/
    env.dart              Compile-time config from --dart-define
    money.dart            Decimal conversion, formatting, rounding rules
    dates.dart            Date-only helpers (never .toLocal() a statement date)
    router.dart           go_router config and the auth redirect guard
    supabase_client.dart  Client init and the top-level `supabase` getter
    theme.dart            Material 3, seeded from a teal-green
    icons.dart            The app's icon vocabulary -- Phosphor icons,
                          category icon slugs, deterministic category tints
    widgets/
      page_body.dart      Desktop max-width wrapper
  features/
    auth/                 Email one-time code sign-in
    groups/               List, detail, settings, create, join by link
    expenses/             Add and edit form, split editor, split logic
    balances/             Balances tab, settle up, debt simplification
    insights/             Monthly category breakdown
    recurring/            Recurring templates
    import/               Bank statement import: logic / data / providers / ui
    labels/                Category + tag management (the group's 4th tab)
    realtime/             Postgres change subscription per group
  models/                 Plain Dart classes mirroring DB rows
supabase/
  migrations/             Numbered SQL, the schema's source of truth
test/                     Unit tests for logic, widget tests for screens
docs/
  statement-import.md     Import pipeline design and fingerprint threat model
  categories-and-tags.md  Category/tag data model, icon vocabulary
  push-notifications.md   FCM setup handoff, see "Not built yet"
.github/workflows/        Test, web deploy, Android APK build
```

---

## Local development

### Prerequisites

* Flutter SDK, stable channel ([install guide](https://docs.flutter.dev/get-started/install/windows))
* A free [Supabase](https://supabase.com) project

### First-time setup

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Apply the schema
#    Run every file in supabase/migrations/ in order, in the Supabase SQL Editor
#    (or `supabase db push`). Then add http://localhost:3000 under
#    Auth > URL Configuration > Redirect URLs.

# 3. Run
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=REDIRECT_URL=http://localhost:3000
```

Copy `.env.example` to `.env.local` to keep your keys to hand. Never commit `.env.local`.

Two dashboard settings matter: **Email OTP Length** has to match `_codeLength` in `login_screen.dart`, and Realtime has to be enabled on the project for live updates to arrive.

### Why `--dart-define` and not a `.env` file

Flutter compiles to a single binary or a JavaScript bundle, and on the web there is no runtime filesystem to read a `.env` from. `--dart-define` bakes the values in as compile-time constants, read through `String.fromEnvironment`, which is the idiomatic Flutter approach and lets them be const-folded and tree-shaken. CI passes them as repository secrets; locally they go in your IDE launch configuration.

The anon key is a public key by design. It is safe in a client bundle precisely because RLS is what actually protects the data. The service role key never appears in this repo.

---

## Testing

```bash
flutter test
```

165 tests, split along the same seam as the architecture:

* **Pure logic tests**, no Flutter and no network: rounding and formatting in `money_test.dart`, date-only parsing in `dates_test.dart`, all three split modes plus their validation states in `split_logic_test.dart`, debt simplification in `settle_test.dart`, and JSON to model mapping in `model_parsing_test.dart`.
* **Statement import tests** in `test/features/import/`: CSV dialect detection, field parsing, merchant-rule precedence, the review-to-plan builder, and the fingerprint. The fingerprint test pins `normalizeReference()` against known vectors, so a change that would silently invalidate every stored fingerprint fails the build instead.
* **Widget tests** for the screens, including a smoke test that pumps each one. `test/support/test_supabase.dart` initialises a throwaway Supabase instance pointed at localhost and stubs the plugin channels `Supabase.initialize()` touches, so screens that read `supabase.auth.currentUser` while building can be pumped without a network call. `currentUser` is null, which is the logged-out state.

Keeping the money rules in pure functions is what makes this cheap: the interesting logic is covered by fast tests that need no database, no mock HTTP layer and no widget tree.

## CI/CD and distribution

* **`test.yml`** runs `flutter analyze` and `flutter test` on every push and pull request. It is kept separate from the deploy workflow on purpose: it needs no secrets, so it stays green and fast on forks and on PRs from any branch.
* **`deploy-web.yml`** builds the web bundle on every push and pull request against `main`, and deploys to Cloudflare Pages only on a push to `main` and only once `CLOUDFLARE_API_TOKEN` is set. Until then the build still runs and validates the app, so the pipeline stays green rather than failing on missing credentials.
* **`build-apk.yml`** builds a release APK on demand and on any `v*` tag, uploads it as an artifact, and attaches it to the GitHub Release for tag builds. The Android package name is `com.tally.app`.

Required repository secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `REDIRECT_URL`, plus `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` for deployment.

## Stack

| Layer | Choice |
|---|---|
| App | Flutter (Dart), web and Android from one codebase |
| State | Riverpod v2, non-codegen |
| Routing | go_router |
| Money | `package:decimal` |
| Backend | Supabase: Postgres, Auth, Realtime, Storage |
| Statement parsing | `csv` (RFC 4180), `file_picker`, `crypto` (SHA-256) |
| Scheduling | pg_cron |
| Hosting | Cloudflare Pages |
| Distribution | GitHub Releases APK |

## Not built yet

* **Background push notifications.** The `device_tokens` table and its RLS exist, and live in-app updates already work through Realtime without Firebase. The rest needs a Firebase project and credentials that cannot be scaffolded without an account, and adding Firebase to Android without `google-services.json` breaks the Gradle build, so it is written up as a handoff in [`docs/push-notifications.md`](docs/push-notifications.md) rather than left half-wired.
* **Multi-currency.** Every money table carries a `currency` column defaulting to CAD, but nothing converts between currencies yet.
* **Removing members** and transferring group ownership.
* **PDF statement import.** The import pipeline is already behind a `StatementParser` interface (`canParse` / `parse`, bytes not files), so a `PdfStatementParser` added to one list needs no change to the review UI, the merchant rules or the fingerprinting. It has to parse client-side to stay inside the privacy boundary, which rules out native-only libraries.

# EXP Share

A free, cross-platform expense-splitting app built with Flutter and Supabase. Think Splitwise — no subscriptions, no ads, self-owned data.

Built as a portfolio project. Runs on web and Android from a single codebase.

## Features (in progress)

- [x] Magic-link authentication (no passwords)
- [x] Create groups, log expenses
- [ ] Full Splitwise-style splitting — equal, exact amounts, percentages
- [ ] Guest members (no account required)
- [ ] Balances view + settle up
- [ ] Monthly category breakdown
- [ ] Recurring expenses
- [ ] Android + push notifications

## Stack

| Layer | Choice |
|---|---|
| App | Flutter (Dart) — web + Android |
| State | Riverpod v2 |
| Routing | go_router |
| Backend | Supabase (Postgres + Auth + Realtime) |
| Hosting | Cloudflare Pages (web) |
| Distribution | GitHub Releases APK (Android) |

## Local development

### Prerequisites

- Flutter SDK (stable channel) — [install guide](https://docs.flutter.dev/get-started/install/windows)
- A free [Supabase](https://supabase.com) project

### First-time setup

```bash
# 1. Install Flutter dependencies
flutter pub get

# 2. Run the database migration
#    Paste supabase/migrations/0001_init.sql into your Supabase SQL Editor and run it.
#    Then add http://localhost:3000 to Auth > URL Configuration > Redirect URLs.

# 3. Start the app
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=REDIRECT_URL=http://localhost:3000
```

Copy `.env.example` to `.env.local` to keep your keys handy — never commit `.env.local`.

### Why `--dart-define` instead of a `.env` file?

Flutter compiles to a single binary (or JavaScript bundle). `--dart-define` bakes constants in at compile time, which is the idiomatic Flutter approach. CI/CD passes these as secrets; locally you add them to your launch configuration.

## Project structure

```
lib/
  main.dart
  app.dart
  core/           # Supabase client, router, theme, money utils
  features/
    auth/         # Magic-link login screen
    groups/       # Group list, detail, create dialog
    expenses/     # Add expense screen
    balances/     # (Push 3) Who owes whom
    insights/     # (Push 4) Monthly category breakdown
    recurring/    # (Push 4) Recurring expense templates
    notifications/# (Push 5) FCM push notifications
  models/         # Plain Dart classes mirroring DB rows
supabase/
  migrations/     # Version-controlled SQL — source of truth for the schema
  functions/      # Edge Functions: cron-tick (recurring), send-push (FCM)
```

## Database

Schema lives in `supabase/migrations/`. Every table has Row Level Security enabled — users can only read and write data in groups they belong to.

Key design decision: `expenses` and `expense_splits` reference `group_members.id` (a surrogate PK), not `profiles.id` directly. This makes guest members (people without accounts) first-class participants in any expense or split.

## Money handling

All amounts are `numeric(12,2)` in Postgres and `package:decimal` in Dart. `double` is never used for currency — floating-point rounding errors in financial math are a real problem.

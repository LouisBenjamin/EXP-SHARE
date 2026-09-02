# Statement import

Import a bank CSV, auto-tag the transactions, and promote the shared ones into
group expenses. Built for the case where roommates share one credit card and
want to split the groceries off it.

## The privacy boundary

Raw statement data never reaches the server. The CSV is parsed on device and
held in screen state for the review session only — never uploaded, never
written to disk. Closing the screen discards it.

Exactly two things cross the wire:

| | What it holds | Where |
|---|---|---|
| `merchant_rules` | Merchant *name patterns* only — no amounts, dates, references, card numbers | Supabase, per group |
| `expenses.source_fingerprint` | An opaque SHA-256 digest | Supabase, on promoted expenses |

Everything else — merchant city, card number, reference number, category
description, the rows you chose *not* to import — stays on the device and is
gone when you leave the screen.

## Deduplication

Two layers, and the important one is server-side.

**1. Already promoted.** `source_fingerprint` is
`SHA-256(group_id + ':' + normalized_reference_number)`, computed on the
client. Before review, the app fetches the group's existing fingerprints and
marks matching rows *Already imported* with a disabled checkbox.

This is fetched rather than remembered locally on purpose. The case the feature
exists for is two roommates importing the same shared-card statement from two
phones: the second device has no local record of what the first one did, but it
can read the group's hashes. It also means dedup works immediately on a new
browser or a reinstalled app, which a local database could not do.

A partial unique index backstops the race where two devices commit at the same
moment:

```sql
create unique index expenses_source_fingerprint_key
  on expenses (group_id, source_fingerprint)
  where source_fingerprint is not null and deleted_at is null;
```

**2. Skip rules.** A merchant rule with `action = 'skip'` means a merchant is
never offered — the right tool for "my hobby shop is never a shared expense",
and group-synced so every roommate gets it.

### Why the index is partial on two conditions

`source_fingerprint is not null` leaves hand-entered expenses unconstrained and
allows many nulls.

`deleted_at is null` means **deleting an imported expense makes it importable
again**. That is intended. Without the clause, a soft-deleted row would block
its own transaction forever, with no visible expense to explain why — an
unfixable dead end. The cost is that delete-then-reimport creates a second
expense. That is the correct trade: the constraint exists to stop accidental
double-charging across devices, not to act as a tombstone.

> ⚠️ The `on conflict` clause in `import_expenses` repeats this predicate
> **verbatim**. Postgres will not use a partial unique index as a conflict
> arbiter otherwise, and the mismatch fails at *runtime*, not at migration
> time. Keep the two in sync — they are adjacent in `0011_import.sql` for
> exactly this reason.

### Threat model for the fingerprint

- **One-way.** Nothing about the merchant, amount, card, or date is recoverable
  from the digest.
- **Not brute-forceable.** The hashed input is a ~23-character bank reference
  number. Hashing something low-entropy instead — a merchant name, say — would
  be trivially reversible with a wordlist, which is why the reference number is
  the input and nothing else is.
- **Not correlatable across groups.** The group id is mixed in, so the same
  transaction produces different digests in different groups.
- **The server cannot verify it.** Structurally unavoidable: verifying it would
  require sending the reference number, which is the thing this design exists
  to avoid. The server trusts the digest. The blast radius of a forged one is a
  group the caller is already a member of — they could block a transaction they
  could equally have imported and deleted.
- **Changing the normalisation invalidates every stored fingerprint.**
  `normalizeReference` is pinned by known vectors in
  `test/features/import/fingerprint_test.dart`. If those fail, stop.

## CSV parsing

Columns are mapped **by name through an alias table**, never by position, because
the same bank exports the same data under different headings depending on which
screen you download from:

| Field | Known spellings |
|---|---|
| date | `Date`, `Transaction Date` |
| status | `Status`, `Activity Status` |
| category | `Merchant Category`, `Merchant Category Description` |

Supporting another bank is a new alias, not a new parser. Unknown columns are
ignored, so an export that gains columns still imports.

Handled quirks, all seen in real files:

- A UTF-8 BOM on the first header cell.
- Fully-quoted exports where the reference arrives as `"55259..."` with the
  quote characters still attached. References are stored **normalized**, or the
  same transaction would fingerprint differently per export and dedup would
  silently stop working.
- `shouldParseNumbers` is **false**. A 23-digit reference exceeds int64 and
  would be silently corrupted through a double.
- Amounts as `$66.82`, `-$1000.00` (sign *before* the symbol), `$1,234.56`,
  `($5.00)`.
- Payments and refunds (negative amounts) are dropped at parse time —
  `expenses.amount` has `check (amount > 0)`, so they could never become shared
  expenses.

Nothing throws. Every function returns a result object with `valid` and a
human-readable `status`, matching the `SplitOutcome` convention, so one bad row
costs one row instead of the file.

## Dates

`occurred_on` is the **transaction date**, not the posted date. The posted date
is a bank settlement artifact that can land days later in a different month,
which would scramble the Insights monthly buckets. The posted date is parsed
and kept in memory but never sent.

Parsing tries ISO first, then slash/dash forms (first component > 12 forces
day-first, otherwise month-first), then a named month. Every real sample is
ISO, so the rest is defensive — deliberately no column-wide format inference,
which sounds clever and has no data behind it.

Date-only values stay date-only. Never `.toLocal()` a statement date or compare
it against `DateTime.now()`; see the note in `lib/core/dates.dart`.

## Merchant rules, a.k.a. tags

A rule — user-facing name **tag**, table name still `merchant_rules` —
decides two things for a matched merchant: which category tags it, and
whether it is offered for sharing at all (`share` / `skip`). Tags are managed
from the **Labels** tab on the group screen (`lib/features/labels/`), not a
screen under Import any more; `/import/rules` redirects there for anyone with
the old link. See [`categories-and-tags.md`](categories-and-tags.md) for the
full data model and why tags and merchant rules are the same table.

Matching is substring-based on a normalized name, because merchant names carry
store and terminal noise — `COSTCO WHOLESALE W515` and `W521` are the same
warehouse, and processors prepend their own tag (`GOOGLE*MTG LIFE COUNT`).

Precedence is **priority ascending, then longer pattern**, so a narrow
`COSTCO GAS` rule beats a broad `COSTCO` one without anyone tuning numbers.
The merchant category description is matched as a weaker second pass.

Two normalisers exist and must not be merged:

- `normalizeMerchant` — case and whitespace only. Used for **matching**, so a
  `GOOGLE` rule still matches `GOOGLE*Spotify Music`.
- `suggestRulePattern` — additionally strips processor prefixes and store
  codes. Used **only** to prefill the rule dialog, so a saved rule covers every
  Costco rather than the one branch the user was looking at.

An unmatched row is still offered, just untagged. Silently hiding a transaction
from someone reviewing a statement is worse than showing it.

Rules are **group-scoped**, not per-device, so everyone on a shared card tags
the same merchant the same way instead of each person re-tagging every month.
Regex is deliberately not supported: one roommate's bad pattern would break
everyone's import.

The same rules also drive `matchTagCategory`, which the Add-expense form calls
as you type a description — a manual expense gets the same autofill a
statement import does, without the category-description fallback pass (there's
no second text source to fall back to). A skip-action tag is ignored there: it
only means "never offer during import".

## Adding PDF support (phase 2)

The pipeline is already behind an interface:

```dart
abstract interface class StatementParser {
  String get label;
  bool canParse(String fileName, Uint8List bytes);
  StatementParseResult parse(Uint8List bytes);
}

const kStatementParsers = <StatementParser>[CsvStatementParser()];
```

Add a `PdfStatementParser` to that list and nothing else changes — not the
review UI, not the rules, not the fingerprinting. It must parse client-side
(the privacy boundary rules out a server-side parser) and work on both web and
Android, which means a pure-Dart library; `pdf_text` is native-only and will
not work on web.

Parsers take **bytes, never a `File`**: on web a picked file has no path, and
the app has no `dart:io` anywhere.

## Files

```
lib/features/import/
  logic/          pure, no I/O — csv_dialect, field_parsers,
                  statement_parser, fingerprint, merchant_rules, import_plan
  data/           import_repository, merchant_rules_repository
  providers/      merchantRulesProvider, importedFingerprintsProvider
  ui/             import_screen, import_review_list
lib/features/labels/ui/    labels_tab, labels_screen, category_dialog, tag_dialog
lib/core/dates.dart
supabase/migrations/0011_import.sql, 0012_categories.sql
test/features/import/
test/features/labels/
```

Everything in `logic/` imports neither Supabase nor Flutter, which is what
makes it testable with no harness — the same arrangement as
`lib/features/expenses/split_logic.dart`.

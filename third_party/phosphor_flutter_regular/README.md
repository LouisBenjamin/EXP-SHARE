# phosphor_flutter (Regular-only fork)

Vendored copy of [phosphor_flutter](https://pub.dev/packages/phosphor_flutter) 2.1.0,
used via a `dependency_overrides` entry in the app's `pubspec.yaml`.

Tally only ever uses `PhosphorIconsRegular` (see `lib/core/icons.dart`), but
upstream's own `pubspec.yaml` declares all six weight fonts — Bold, Duotone,
Fill, Light, Regular, Thin — unconditionally. Flutter bundles whatever a
package's pubspec declares regardless of which Dart classes the app imports,
so icon tree-shaking (which only trims the glyph set *within* a font that's
already going to ship) can't remove an entire unused font family. That left
~2.2MB of Bold/Duotone/Fill/Light/Thin font data in every build that nothing
in the app ever renders.

This fork is byte-for-byte the same Dart API (including the unused weight
classes, which still exist and still compile — they just have no backing
font file any more, so rendering one would show tofu/fallback glyphs). The
only change is in `pubspec.yaml` and `lib/fonts/`: the five unused `.ttf`
files are deleted and their `flutter: fonts:` entries removed, keeping only
`PhosphorRegular` → `lib/fonts/Phosphor.ttf`.

**If the app ever needs a non-Regular weight**, don't hand-edit this fork —
delete this directory and the `dependency_overrides` entry in the root
`pubspec.yaml`, and go back to depending on upstream `phosphor_flutter`
directly (`flutter pub add phosphor_flutter`).

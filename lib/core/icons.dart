import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// The app's single icon vocabulary. Category icons are looked up by the slug
// stored in categories.icon; app chrome uses the AppIcons constants below.
// Everything here comes from PhosphorIconsRegular's static-const accessors —
// never PhosphorIcons.regular.xyz, which is a getter and defeats
// --tree-shake-icons.

// Curated category icons, grouped by theme. Add to this map (never remove a
// key still referenced by a stored category row) when a new use case needs an
// icon the picker doesn't already offer.
const Map<String, IconData> kCategoryIcons = {
  // Food & drink
  'fork-knife': PhosphorIconsRegular.forkKnife,
  'shopping-cart': PhosphorIconsRegular.shoppingCart,
  'coffee': PhosphorIconsRegular.coffee,
  'pizza': PhosphorIconsRegular.pizza,
  'wine': PhosphorIconsRegular.wine,
  'cooking-pot': PhosphorIconsRegular.cookingPot,
  'popcorn': PhosphorIconsRegular.popcorn,

  // Housing
  'house': PhosphorIconsRegular.house,
  'house-line': PhosphorIconsRegular.houseLine,
  'couch': PhosphorIconsRegular.couch,
  'lightbulb': PhosphorIconsRegular.lightbulb,
  'drop': PhosphorIconsRegular.drop,
  'broom': PhosphorIconsRegular.broom,
  'wrench': PhosphorIconsRegular.wrench,
  'hammer': PhosphorIconsRegular.hammer,

  // Transportation
  'car': PhosphorIconsRegular.car,
  'car-simple': PhosphorIconsRegular.carSimple,
  'gas-pump': PhosphorIconsRegular.gasPump,
  'bus': PhosphorIconsRegular.bus,
  'train': PhosphorIconsRegular.train,
  'taxi': PhosphorIconsRegular.taxi,
  'bicycle': PhosphorIconsRegular.bicycle,
  'scooter': PhosphorIconsRegular.scooter,
  'motorcycle': PhosphorIconsRegular.motorcycle,

  // Entertainment & leisure
  'film-slate': PhosphorIconsRegular.filmSlate,
  'music-notes': PhosphorIconsRegular.musicNotes,
  'game-controller': PhosphorIconsRegular.gameController,
  'ticket': PhosphorIconsRegular.ticket,
  'barbell': PhosphorIconsRegular.barbell,
  'soccer-ball': PhosphorIconsRegular.soccerBall,
  'basketball': PhosphorIconsRegular.basketball,
  'palette': PhosphorIconsRegular.palette,
  'flower-lotus': PhosphorIconsRegular.flowerLotus,

  // Health
  'heartbeat': PhosphorIconsRegular.heartbeat,
  'stethoscope': PhosphorIconsRegular.stethoscope,
  'pill': PhosphorIconsRegular.pill,
  'first-aid': PhosphorIconsRegular.firstAid,
  'tooth': PhosphorIconsRegular.tooth,

  // Travel
  'airplane-tilt': PhosphorIconsRegular.airplaneTilt,
  'suitcase': PhosphorIconsRegular.briefcase,
  'umbrella': PhosphorIconsRegular.umbrella,

  // Shopping
  'shopping-bag-open': PhosphorIconsRegular.shoppingBagOpen,
  't-shirt': PhosphorIconsRegular.tShirt,
  'gift': PhosphorIconsRegular.gift,

  // Bills & finance
  'lightning': PhosphorIconsRegular.lightning,
  'phone': PhosphorIconsRegular.phone,
  'bank': PhosphorIconsRegular.bank,
  'credit-card': PhosphorIconsRegular.creditCard,
  'wallet': PhosphorIconsRegular.wallet,
  'currency-circle-dollar': PhosphorIconsRegular.currencyCircleDollar,

  // People & misc
  'graduation-cap': PhosphorIconsRegular.graduationCap,
  'baby': PhosphorIconsRegular.baby,
  'dog': PhosphorIconsRegular.dog,
  'cat': PhosphorIconsRegular.cat,
  'briefcase': PhosphorIconsRegular.briefcase,
  'dots-three-outline': PhosphorIconsRegular.dotsThreeOutline,
  'tag': PhosphorIconsRegular.tag,
};

// Material icon-name slugs seeded by the original 0001 migration. Migration
// 0012 rewrites the seeded rows to Phosphor slugs, but a group category
// created before that migration ran (or a stale cached row) may still carry
// one of these — resolve it to its Phosphor equivalent rather than falling
// back to the generic tag icon.
const Map<String, String> _legacyIconAliases = {
  'restaurant': 'fork-knife',
  'shopping_cart': 'shopping-cart',
  'home': 'house',
  'directions_car': 'car',
  'movie': 'film-slate',
  'favorite': 'heartbeat',
  'flight': 'airplane-tilt',
  'shopping_bag': 'shopping-bag-open',
  'bolt': 'lightning',
  'more_horiz': 'dots-three-outline',
  'label': 'tag',
};

// Resolves a category's stored icon slug to a Phosphor glyph. Unknown slugs
// (including a blank default) fall back to the generic tag icon rather than
// throwing, since the slug is free-form data from the database.
IconData iconForCategory(String slug) {
  final resolved = kCategoryIcons[slug] ?? kCategoryIcons[_legacyIconAliases[slug]];
  return resolved ?? PhosphorIconsRegular.tag;
}

// A deterministic tonal background for a category avatar, derived from its
// id so the same category always renders the same colour without needing a
// colour column or picker. Hue spread keeps adjacent categories visually
// distinct; saturation/lightness stay theme-appropriate.
Color categoryTint(String categoryId, Brightness brightness) {
  final hue = (categoryId.hashCode % 360).abs().toDouble();
  return HSLColor.fromAHSL(
    1,
    hue,
    0.55,
    brightness == Brightness.dark ? 0.26 : 0.85,
  ).toColor();
}

// A readable foreground colour for content drawn on top of [categoryTint].
Color onCategoryTint(Color tint) =>
    ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
        ? Colors.white
        : Colors.black87;

// Semantic icon constants for app chrome (app bars, buttons, empty states),
// so the whole app draws from one icon vocabulary instead of scattering
// PhosphorIconsRegular.* literals through the UI.
abstract final class AppIcons {
  const AppIcons._();

  static const add = PhosphorIconsRegular.plus;
  static const edit = PhosphorIconsRegular.pencilSimple;
  static const delete = PhosphorIconsRegular.trash;
  static const close = PhosphorIconsRegular.x;
  static const info = PhosphorIconsRegular.info;
  static const success = PhosphorIconsRegular.checkCircle;
  static const arrowForward = PhosphorIconsRegular.arrowRight;
  static const signIn = PhosphorIconsRegular.signIn;
  static const groupAdd = PhosphorIconsRegular.usersFour;
  static const personAdd = PhosphorIconsRegular.userPlus;
  static const repeat = PhosphorIconsRegular.repeat;
  static const insights = PhosphorIconsRegular.chartBar;
  static const upload = PhosphorIconsRegular.uploadSimple;
  static const settings = PhosphorIconsRegular.gearSix;
  static const receipt = PhosphorIconsRegular.receipt;
  static const key = PhosphorIconsRegular.key;
  static const copy = PhosphorIconsRegular.copy;
  static const share = PhosphorIconsRegular.shareNetwork;
  static const email = PhosphorIconsRegular.envelopeSimple;
  static const doneAll = PhosphorIconsRegular.checks;
  static const tag = PhosphorIconsRegular.tag;
  static const bookmarkAdd = PhosphorIconsRegular.bookmarkSimple;
  static const filterOff = PhosphorIconsRegular.funnelX;
  static const downloadDone = PhosphorIconsRegular.cloudCheck;
  static const dateRange = PhosphorIconsRegular.calendarBlank;
  static const block = PhosphorIconsRegular.prohibit;
  static const camera = PhosphorIconsRegular.camera;
  static const linkOff = PhosphorIconsRegular.linkBreak;
  static const search = PhosphorIconsRegular.magnifyingGlass;
}

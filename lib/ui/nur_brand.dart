import 'package:material_ui/material_ui.dart';

/// Nur Connect's black-and-gold look, measured from the mobile app's design so
/// the Windows client reads as the same product.
abstract final class NurBrand {
  /// The accent gold of icons, the power glyph and selected controls.
  static const gold = Color(0xFFE0A045);

  /// The softer gold of rings, progress bars and outlines.
  static const softGold = Color(0xFFC69F5A);

  /// Gold dimmed for an idle ring or a disabled accent.
  static const dimGold = Color(0xFF6B5531);

  /// The warm wash behind a selected row.
  static const selected = Color(0xFF261E11);

  static const page = Color(0xFF000000);
  static const card = Color(0xFF0E0E0E);
  static const block = Color(0xFF171717);
  static const inset = Color(0xFF212121);
  static const hairline = Color(0xFF242424);

  static const text = Color(0xFFF2EEE8);
  static const muted = Color(0xFF9C968C);

  /// The power button's face, lit from above.
  static const faceLight = Color(0xFF221E16);
  static const faceDark = Color(0xFF080808);

  /// Fixed rather than seeded: a seed would drift the gold and tint the black.
  static const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: gold,
    onPrimary: Color(0xFF000000),
    primaryContainer: selected,
    onPrimaryContainer: Color(0xFFF5E6C8),
    secondary: softGold,
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF2A2416),
    onSecondaryContainer: Color(0xFFF0E2C4),
    tertiary: Color(0xFFD9B26F),
    onTertiary: Color(0xFF000000),
    tertiaryContainer: Color(0xFF2E2615),
    onTertiaryContainer: Color(0xFFF5E6C8),
    error: Color(0xFFF2726B),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFF3B1412),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: page,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceDim: page,
    surfaceBright: Color(0xFF2A2721),
    surfaceContainerLowest: page,
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainer: card,
    surfaceContainerHigh: block,
    surfaceContainerHighest: inset,
    outline: Color(0xFF3A352C),
    outlineVariant: hairline,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: text,
    onInverseSurface: Color(0xFF141414),
    inversePrimary: Color(0xFF8A5F12),
    surfaceTint: Color(0x00000000),
  );
}

/// Whether [primaryColor] picks the brand look rather than a seeded scheme.
bool isNurBrandColor(int? primaryColor) => primaryColor == nurGoldColor;

/// The theme's brand swatch, first in the color list.
const nurGoldColor = 0xFFE0A045;

/// The light blue FlClashX shipped as its default; configs that still carry it
/// never chose a color, so they move to the brand look.
const legacyDefaultPrimaryColor = 0xFF03A9F4;

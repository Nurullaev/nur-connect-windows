import 'dart:math' as math;

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/nur_brand.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the default color is the brand gold and the first swatch', () {
    expect(defaultPrimaryColor, nurGoldColor);
    expect(defaultPrimaryColors.first, nurGoldColor);
    expect(defaultPrimaryColors, isNot(contains(legacyDefaultPrimaryColor)));
    expect(NurBrand.colorScheme.primary, const Color(nurGoldColor));
  });

  test('the brand gold gives the fixed dark scheme for both brightnesses', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The app takes the gold from its config; a bare container has no color.
    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(primaryColor: defaultPrimaryColor));

    expect(
      container.read(genColorSchemeProvider(Brightness.light)),
      NurBrand.colorScheme,
    );
    expect(
      container.read(genColorSchemeProvider(Brightness.dark)),
      NurBrand.colorScheme,
    );
    expect(
      container.read(
        genColorSchemeProvider(
          Brightness.light,
          color: const Color(nurGoldColor),
        ),
      ),
      NurBrand.colorScheme,
    );
  });

  test('the brand is dark whatever the theme mode says', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(themeSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            themeMode: ThemeMode.light,
            primaryColor: defaultPrimaryColor,
          ),
        );

    expect(container.read(currentBrightnessProvider), Brightness.dark);

    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(primaryColor: 0xFF007AFF));
    expect(container.read(currentBrightnessProvider), Brightness.light);
    expect(
      container.read(genColorSchemeProvider(Brightness.light)).brightness,
      Brightness.light,
    );
  });

  test('the system accent falling back to gold still seeds light', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(primaryColor: null));

    final light = container.read(genColorSchemeProvider(Brightness.light));
    expect(light.brightness, Brightness.light);
    expect(light, isNot(NurBrand.colorScheme));
  });

  test('the FlClashX blue default moves to the brand gold', () {
    final moved = ThemeProps.safeFromJson({
      'primaryColor': legacyDefaultPrimaryColor,
      'primaryColors': [legacyDefaultPrimaryColor, 0xFF007AFF],
    });
    expect(moved.primaryColor, nurGoldColor);
    expect(moved.primaryColors, [nurGoldColor, 0xFF007AFF]);

    final kept = ThemeProps.safeFromJson({
      'primaryColor': 0xFF123456,
      'primaryColors': [0xFF123456],
    });
    expect(kept.primaryColor, 0xFF123456);
    expect(kept.primaryColors, [0xFF123456]);

    expect(ThemeProps.safeFromJson({}).primaryColor, isNull);
  });

  test('brand text stays readable and the surfaces climb in order', () {
    const scheme = NurBrand.colorScheme;
    expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(7));
    expect(
      _contrast(scheme.onSurfaceVariant, scheme.surfaceContainer),
      greaterThan(4.5),
    );
    expect(
      _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
      greaterThan(4.5),
    );
    expect(_contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
    expect(
      _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
      greaterThan(7),
    );
    expect(
      _contrast(scheme.primary, scheme.surfaceContainer),
      greaterThan(4.5),
    );

    final surfaces = [
      scheme.surface,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ].map((color) => color.computeLuminance()).toList();
    expect(surfaces, orderedEquals([...surfaces]..sort()));
  });
}

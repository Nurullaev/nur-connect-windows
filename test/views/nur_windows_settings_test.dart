import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/nur_windows_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  testWidgets(
    'Windows startup controls write the existing persisted settings',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [profilesProvider.overrideWith(TestProfiles.new)],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1200, 1600);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('en'),
            child: NurWindowsSettings(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.settings), findsOne);
      expect(container.read(appSettingProvider).autoLaunch, isFalse);
      await tester.tap(find.text(l10n.autoLaunch));
      await tester.pumpAndSettle();
      expect(container.read(appSettingProvider).autoLaunch, isTrue);
      expect(container.read(appSettingProvider).minimizeOnExit, isFalse);
      await tester.tap(find.text(l10n.minimizeOnExit));
      await tester.pumpAndSettle();
      expect(container.read(appSettingProvider).minimizeOnExit, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

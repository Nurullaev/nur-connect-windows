import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/nur_servers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Proxies extends ProxiesAction {
  final chosen = <String>[];
  final tested = <String>[];

  @override
  void changeProxyDebounce(String groupName, String proxyName) {
    chosen.add(proxyName);
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, proxyName);
  }

  @override
  Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
    tested.addAll(proxies.map((item) => item.name));
  }
}

void main() {
  testWidgets('local search preserves the page query and the chosen server', (
    tester,
  ) async {
    const profile = Profile(
      id: 1,
      label: 'Plan',
      autoUpdateDuration: Duration.zero,
    );
    final action = _Proxies();
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        proxiesActionProvider.overrideWith(() => action),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = const Size(1100, 900);
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 1;
    container.listen(groupsProvider, (_, _) {});
    container.read(groupsProvider.notifier).value = [
      const Group(
        name: 'Servers',
        type: GroupType.Selector,
        hidden: false,
        now: 'Finland',
        all: [
          Proxy(name: 'Finland', type: 'ss'),
          Proxy(name: 'US fixed', type: 'ss'),
        ],
      ),
    ];
    container.listen(queryProvider(QueryTag.proxies), (_, _) {});
    container.read(queryProvider(QueryTag.proxies).notifier).value =
        'other-page';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: NurServersView(picker: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nur-server-search')),
      'US',
    );
    await tester.pumpAndSettle();
    expect(find.text('US fixed'), findsOne);
    expect(find.text('Finland'), findsNothing);
    expect(container.read(queryProvider(QueryTag.proxies)), 'other-page');
    await tester.tap(find.text('US fixed'));
    await tester.pumpAndSettle();
    expect(action.chosen, ['US fixed']);
    expect(
      container.read(profilesProvider).single.selectedMap['Servers'],
      'US fixed',
    );
    await tester.tap(find.byTooltip(currentAppLocalizations.delayTest).last);
    await tester.pumpAndSettle();
    expect(action.tested, ['US fixed']);
    expect(
      container.read(profilesProvider).single.selectedMap['Servers'],
      'US fixed',
    );
    expect(tester.takeException(), isNull);
  });
}

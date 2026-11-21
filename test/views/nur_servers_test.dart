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
  for (final (picker, mode) in [
    (true, Mode.rule),
    (false, Mode.rule),
    (false, Mode.global),
  ]) {
    testWidgets(
      'server page picker=$picker mode=$mode lays out and preserves picks',
      (tester) async {
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
            coreStatusProvider.overrideWithBuild(
              (_, _) => CoreStatus.connected,
            ),
            patchClashConfigProvider.overrideWithBuild(
              (_, _) => PatchClashConfig(mode: mode),
            ),
          ],
        );
        addTearDown(container.dispose);
        globalState.container = container;
        tester.view.physicalSize = Size(picker ? 1100 : 430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        container.read(viewSizeProvider.notifier).value = Size(
          picker ? 1100 : 430,
          900,
        );
        container.listen(currentProfileIdProvider, (_, _) {});
        container.read(currentProfileIdProvider.notifier).value = 1;
        container.listen(groupsProvider, (_, _) {});
        container.read(groupsProvider.notifier).value = [
          const Group(
            name: 'GLOBAL',
            type: GroupType.Selector,
            hidden: false,
            now: 'Finland',
            all: [
              Proxy(name: 'DIRECT', type: 'Direct'),
              Proxy(name: 'REJECT', type: 'Reject'),
              Proxy(name: 'Finland', type: 'ss'),
              Proxy(name: 'US fixed', type: 'ss'),
            ],
          ),
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
            child: TestApp(
              locale: const Locale('en'),
              child: NurServersView(picker: picker),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('GLOBAL'), findsNothing);
        expect(find.text('DIRECT'), findsNothing);
        expect(find.text('REJECT'), findsNothing);
        expect(find.text('Finland'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('nur-server-search'))).dy,
          greaterThan(
            tester
                .getBottomLeft(find.text(currentAppLocalizations.nurServers))
                .dy,
          ),
        );
        final groupName = mode == Mode.global ? 'GLOBAL' : 'Servers';
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
          container.read(profilesProvider).single.selectedMap[groupName],
          'US fixed',
        );
        await tester.tap(
          find.byTooltip(currentAppLocalizations.delayTest).last,
        );
        await tester.pumpAndSettle();
        expect(action.tested, ['US fixed']);
        expect(
          container.read(profilesProvider).single.selectedMap[groupName],
          'US fixed',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an ended plan shows the panel notices and renewal, not servers',
    (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final profile = Profile(
        id: 1,
        label: 'Plan',
        autoUpdateDuration: Duration.zero,
        subscriptionInfo: SubscriptionInfo(
          expire: yesterday.millisecondsSinceEpoch ~/ 1000,
        ),
        providerHeaders: const {'bot-url': 'https://t.me/example_bot'},
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
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      container.read(viewSizeProvider.notifier).value = const Size(430, 900);
      container.listen(currentProfileIdProvider, (_, _) {});
      container.read(currentProfileIdProvider.notifier).value = 1;
      container.listen(groupsProvider, (_, _) {});
      container.read(groupsProvider.notifier).value = [
        const Group(
          name: 'Nur VPN',
          type: GroupType.Selector,
          hidden: false,
          now: 'Plan over, says the panel',
          all: [
            Proxy(name: 'Plan over, says the panel', type: 'vless'),
            Proxy(name: 'Renew in the bot', type: 'vless'),
            Proxy(name: 'Inner', type: 'Selector'),
            Proxy(name: 'DIRECT', type: 'Direct'),
          ],
        ),
        const Group(
          name: 'Inner',
          type: GroupType.Selector,
          hidden: false,
          now: 'Renew in the bot',
          all: [Proxy(name: 'Renew in the bot', type: 'vless')],
        ),
      ];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(locale: Locale('en'), child: NurServersView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('nur-servers-expired')), findsOne);
      expect(find.text(currentAppLocalizations.nurSubscriptionEnded), findsOne);
      expect(find.text('Plan over, says the panel'), findsOne);
      expect(find.text('Renew in the bot'), findsOne);
      expect(find.text('DIRECT'), findsNothing);
      expect(find.text('Inner'), findsNothing);
      expect(find.byKey(const ValueKey('nur-server-search')), findsNothing);
      expect(find.byKey(const ValueKey('nur-servers-renew')), findsOne);
      await tester.tap(find.byTooltip(currentAppLocalizations.delayTest).last);
      await tester.pumpAndSettle();
      expect(action.tested, isEmpty);
    },
  );
}

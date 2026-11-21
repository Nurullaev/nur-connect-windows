import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/nur_connect.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/app_paths.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _Setup extends SetupAction {
  final calls = <bool>[];
  Completer<bool>? pending;

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    calls.add(running);
    if (pending != null) return pending!.future;
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return true;
  }
}

const _profile = Profile(
  id: 1,
  label: 'My subscription',
  type: ProfileType.url,
  url: 'https://example.test/private-token',
  autoUpdateDuration: Duration.zero,
);

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('nur-home-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    await useAppPaths(dir);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool profile = true,
    Profile subscription = _profile,
    bool safe = false,
    _Setup? setup,
    Size size = const Size(1200, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles(profile ? [subscription] : []),
        ),
        patchClashConfigProvider.overrideWithBuild(
          (_, _) => const PatchClashConfig(tun: Tun(enable: false)),
        ),
        networkSettingProvider.overrideWithBuild(
          (_, _) => const NetworkProps(systemProxy: false),
        ),
        initProvider.overrideWithBuild((_, _) => true),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        suspendProvider.overrideWithValue(false),
        safeModeProvider.overrideWithValue(safe),
        setupActionProvider.overrideWith(() => setup ?? _Setup()),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = size;
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = profile
        ? 1
        : null;
    container.listen(groupsProvider, (_, _) {});
    container.read(groupsProvider.notifier).value = [
      const Group(
        name: 'Servers',
        type: GroupType.Selector,
        hidden: false,
        now: 'Finland',
        all: [Proxy(name: 'Finland', type: 'ss')],
      ),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          homeBuilder: (child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          ),
          child: const DashboardView(platform: SupportPlatform.Windows),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets(
    'Windows routes to Nur Connect and starts with an import invitation',
    (tester) async {
      await pump(tester, profile: false);
      expect(find.byType(NurConnectDashboard), findsOne);
      expect(find.text(appName), findsOneWidget);
      expect(find.byKey(const ValueKey('nur-welcome')), findsOne);
      expect(find.text(currentAppLocalizations.nurAddSubscription), findsOne);
      expect(find.byKey(const ValueKey('nur-connect-toggle')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows the subscription, selected server and routing hint without its URL',
    (tester) async {
      await pump(tester);
      expect(find.text('My subscription'), findsOne);
      expect(find.text('Finland'), findsOne);
      expect(find.text(currentAppLocalizations.nurTakeoverHint), findsOne);
      expect(find.textContaining('private-token'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'serializes connect presses until the existing setup action completes',
    (tester) async {
      final pending = Completer<bool>();
      final setup = _Setup()..pending = pending;
      await pump(tester, setup: setup);
      final toggle = find.byKey(const ValueKey('nur-connect-toggle'));
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<NurPowerButton>(toggle).onPressed, isNull);
      expect(setup.calls, [true]);
      pending.complete(true);
      await tester.pump();
    },
  );

  testWidgets('connection modes are exclusive and stay fixed while connected', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.text('VPN (TUN)'));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    expect(container.read(networkSettingProvider).systemProxy, isFalse);
    await tester.tap(find.text(currentAppLocalizations.nurProxyMode));
    await tester.pump();
    expect(container.read(patchClashConfigProvider).tun.enable, isFalse);
    expect(container.read(networkSettingProvider).systemProxy, isTrue);
    container.read(runTimeProvider.notifier).value = 1;
    await tester.pump();
    await tester.tap(find.text('VPN (TUN)'), warnIfMissed: false);
    await tester.pump();
    expect(container.read(patchClashConfigProvider).tun.enable, isFalse);
    expect(container.read(networkSettingProvider).systemProxy, isTrue);
  });

  testWidgets('safe mode disables connection', (tester) async {
    await pump(tester, safe: true);
    expect(
      tester
          .widget<NurPowerButton>(
            find.byKey(const ValueKey('nur-connect-toggle')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a connected VPN lights the ring and shows time and speed', (
    tester,
  ) async {
    final container = await pump(tester);
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: true));
    container.read(runTimeProvider.notifier).value = 61000;
    await tester.pump();
    final toggle = find.byKey(const ValueKey('nur-connect-toggle'));
    expect(
      tester.widget<NurPowerButton>(toggle).state,
      NurPowerState.connected,
    );
    expect(tester.widget<NurPowerButton>(toggle).caption, isNotNull);
    expect(find.text(currentAppLocalizations.connected), findsOne);
    expect(find.byKey(const ValueKey('nur-speed')), findsOne);
    expect(find.text(currentAppLocalizations.nurTakeoverHint), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an idle VPN shows a dashed ring and no time', (tester) async {
    final container = await pump(tester);
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: true));
    await tester.pump();
    final button = tester.widget<NurPowerButton>(
      find.byKey(const ValueKey('nur-connect-toggle')),
    );
    expect(button.state, NurPowerState.idle);
    expect(button.caption, isNull);
    expect(button.label, currentAppLocalizations.nurConnect);
    expect(find.text(currentAppLocalizations.disconnected), findsOne);
  });

  testWidgets(
    'a narrow window with large text uses a scrollable single column',
    (tester) async {
      await pump(tester, size: const Size(540, 900), scale: 2);
      expect(find.byType(CustomScrollView), findsOne);
      expect(find.byKey(const ValueKey('nur-home-servers')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an ended plan blocks connecting and offers renewal', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pump(
      tester,
      subscription: _profile.copyWith(
        subscriptionInfo: SubscriptionInfo(
          expire: yesterday.millisecondsSinceEpoch ~/ 1000,
        ),
        providerHeaders: const {
          'bot-url': 'https://t.me/example_bot',
          'support-url': 'https://t.me/example_support',
        },
      ),
    );
    expect(
      tester
          .widget<NurPowerButton>(
            find.byKey(const ValueKey('nur-connect-toggle')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('nur-status'))).data,
      currentAppLocalizations.nurSubscriptionEnded,
    );
    expect(find.text(currentAppLocalizations.nurRenewToConnect), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nur-help-action')),
        matching: find.text(currentAppLocalizations.renew),
      ),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a device limit refusal blocks connecting and offers support', (
    tester,
  ) async {
    await pump(
      tester,
      subscription: _profile.copyWith(
        providerHeaders: const {
          'x-hwid-max-devices-reached': 'true',
          'support-url': 'https://t.me/example_support',
        },
      ),
    );
    expect(
      tester
          .widget<NurPowerButton>(
            find.byKey(const ValueKey('nur-connect-toggle')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('nur-status'))).data,
      currentAppLocalizations.deviceLimitReached,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nur-help-action')),
        matching: find.text(currentAppLocalizations.support),
      ),
      findsOne,
    );
  });

  testWidgets('a plan with time left has no help action', (tester) async {
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    await pump(
      tester,
      subscription: _profile.copyWith(
        subscriptionInfo: SubscriptionInfo(
          expire: nextWeek.millisecondsSinceEpoch ~/ 1000,
        ),
        providerHeaders: const {'bot-url': 'https://t.me/example_bot'},
      ),
    );
    expect(
      tester
          .widget<NurPowerButton>(
            find.byKey(const ValueKey('nur-connect-toggle')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const ValueKey('nur-help-action')), findsNothing);
  });

  testWidgets('the header names the provider and its banner offers a link', (
    tester,
  ) async {
    await pump(
      tester,
      subscription: _profile.copyWith(
        providerHeaders: const {
          'profile-title': 'Incy VPN',
          'banner-text': 'Invite friends, pay less',
          'banner-button-text': 'Invite',
          'banner-button-url': 'tg://resolve?domain=IncyRu_bot&start=partner',
        },
      ),
    );
    expect(find.byKey(const ValueKey('nur-brand')), findsOne);
    expect(find.textContaining('Incy VPN'), findsWidgets);
    expect(find.byKey(const ValueKey('nur-banner')), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nur-banner-action')),
        matching: find.text('Invite'),
      ),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the connect button leads, the card carries the notices, servers follow',
    (tester) async {
      await pump(
        tester,
        size: const Size(440, 1400),
        subscription: _profile.copyWith(
          providerHeaders: const {
            'announce': 'Traffic is free until the end of the month',
            'banner-text': 'Invite friends, pay less',
            'banner-button-text': 'Invite',
            'banner-button-url': 'https://t.me/example_bot?start=partner',
          },
        ),
      );
      Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
      final card = rect('profile-card-dense');
      final banner = rect('nur-banner');
      final announcement = rect('announcement-inline');
      expect(rect('nur-connect-toggle').top, lessThan(card.top));
      expect(card.contains(banner.center), isTrue);
      expect(card.contains(announcement.center), isTrue);
      expect(banner.top, lessThan(announcement.top));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('announcement-inline-text')),
            )
            .textAlign,
        TextAlign.center,
      );
      expect(rect('nur-home-servers-header').top, greaterThan(card.bottom));
      expect(rect('Finland').top, greaterThan(card.bottom));
      expect(find.byKey(const ValueKey('nur-home-servers')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a wide window puts the servers in a column of their own', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 800));
    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
    final panel = rect('nur-home-servers');
    final card = rect('profile-card-dense');
    expect(rect('nur-connect-toggle').center.dx, lessThan(panel.left));
    expect(card.right, lessThan(panel.left));
    expect(card.top, greaterThan(rect('nur-connect-toggle').bottom));
    expect(find.byKey(const ValueKey('Finland')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ended plan shows no server list', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pump(
      tester,
      size: const Size(440, 1400),
      subscription: _profile.copyWith(
        subscriptionInfo: SubscriptionInfo(
          expire: yesterday.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('nur-home-servers-header')), findsNothing);
    expect(find.byKey(const ValueKey('Finland')), findsNothing);
  });

  testWidgets('without a provider name the header keeps the app name', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nur-brand')),
        matching: find.textContaining(appName),
      ),
      findsOne,
    );
    expect(find.byKey(const ValueKey('nur-banner')), findsNothing);
  });
}

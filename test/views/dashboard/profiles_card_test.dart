import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/profile_detail.dart';
import 'package:fl_clash/views/dashboard/widgets/profiles.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/views/profiles/custom/custom.dart';
import 'package:fl_clash/views/profiles/custom/rules.dart';
import 'package:fl_clash/views/proxies/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../../helpers/app_paths.dart';
import '../../helpers/glyph_finders.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

const _gib = 1024 * 1024 * 1024;

class _TestProfileRules extends ProfileRules {
  @override
  Stream<List<Rule>> build(int profileId) => Stream.value(const []);
}

class _TestProxyGroups extends ProxyGroups {
  @override
  Stream<List<ProxyGroup>> build(int profileId) => Stream.value(const []);
}

class _IdleSetupAction extends SetupAction {
  @override
  void autoApplyProfile() {}
}

ExternalProvider _provider(String name, String type, int count) =>
    ExternalProvider(
      name: name,
      type: type,
      count: count,
      vehicleType: 'HTTP',
      updateAt: DateTime(2026),
    );

Profile _profile(
  int id, {
  SubscriptionInfo? info,
  ProfileType type = ProfileType.file,
}) => Profile(
  id: id,
  label: 'P$id',
  type: type,
  url: 'https://sub$id.example.com/link',
  autoUpdateDuration: Duration.zero,
  lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
  subscriptionInfo: info,
);

class _QuietProfilesAction extends ProfilesAction {
  @override
  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {}
}

class _DeletingProfilesAction extends ProfilesAction {
  static final deleted = <int>[];

  @override
  Future<void> deleteProfile(int id) async => deleted.add(id);

  @override
  Future<List<Profile>> providerUsers(Profile profile) async => const [];
}

class _GatedProfilesAction extends ProfilesAction {
  static Completer<void>? gate;

  @override
  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    await gate?.future;
  }
}

void main() {
  late ProviderContainer container;

  setUpAll(() async {
    final home = Directory.systemTemp.createTempSync('profiles_card');
    addTearDown(() => home.deleteSync(recursive: true));
    await useAppPaths(home);
  });

  void setUpProfiles(
    List<Profile> profiles, {
    List<Override> overrides = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        viewSizeProvider.overrideWithBuild((_, _) => const Size(1200, 1000)),
        ...overrides,
      ],
    );
    globalState.container = container;
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value =
        profiles.firstOrNull?.id;
    addTearDown(container.dispose);
  }

  /// The counts are parsed in an isolate, which only runs in real time;
  /// without [until] this waits for the card to stop loading them.
  Future<void> settleCounts(WidgetTester tester, {Finder? until}) async {
    bool done() => until != null
        ? until.evaluate().isNotEmpty
        : find.byType(SkeletonText).evaluate().isEmpty;
    for (var i = 0; i < 40 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    Widget card = const ProfilesCard(),
    double width = 360,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: card),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await settleCounts(tester);
  }

  Future<void> pumpDesktopCard(WidgetTester tester) => pumpCard(
    tester,
    card: const DashboardDensityScope(
      density: DashboardDensity.standard,
      scale: 1,
      child: SizedBox(height: 176, child: ProfilesCard()),
    ),
    width: 300,
  );

  Finder label(String text) => find.text(text, findRichText: true);

  testWidgets('offers to add a profile without profiles', (tester) async {
    setUpProfiles([]);
    await pumpCard(tester);

    expect(find.text('Add profile'), findsOneWidget);

    await pumpDesktopCard(tester);
    expect(find.text('Add profile'), findsOneWidget);
    expect(find.byTooltip('Switch profile'), findsNothing);
  });

  testWidgets('a support page from the panel gets a button beside update', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {'support-url': 'https://help.example.com'},
      ),
    ]);
    await pumpCard(tester);
    expect(find.byTooltip('Support'), findsOneWidget);
    expect(find.byTooltip('Update'), findsOneWidget);

    await pumpDesktopCard(tester);
    expect(find.byTooltip('Support'), findsOneWidget);
  });

  testWidgets('the subscription page from the panel gets a link button', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {
          'support-url': 'https://help.example.com',
          'profile-web-page-url': 'https://my.example.com',
        },
      ),
    ]);
    await pumpCard(tester);

    expect(find.byTooltip('Subscription'), findsOneWidget);
    expect(find.byGlyph(AppGlyphs.link), findsOneWidget);
    // Without account-url there is no site button.
    expect(find.byTooltip('Website'), findsNothing);
    expect(find.byGlyph(AppGlyphs.globe), findsNothing);
    expect(
      tester.getCenter(find.byGlyph(AppGlyphs.link)).dx,
      lessThan(tester.getCenter(find.byGlyph(AppGlyphs.support)).dx),
    );
  });

  testWidgets('site, bot, subscription and support go in that order', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {
          'support-url': 'https://help.example.com',
          'profile-web-page-url': 'https://my.example.com',
          'account-url': 'https://account.example.com',
          'bot-url': 'https://t.me/example_bot',
        },
      ),
    ]);
    for (final pump in <Future<void> Function(WidgetTester)>[
      pumpCard,
      pumpDesktopCard,
    ]) {
      await pump(tester);

      expect(find.byTooltip('Website'), findsOneWidget);
      expect(find.byTooltip('Bot'), findsOneWidget);
      expect(find.byTooltip('Subscription'), findsOneWidget);
      expect(find.byTooltip('Support'), findsOneWidget);
      expect(find.byTooltip('Account'), findsNothing);
      expect(find.byGlyph(AppGlyphs.account), findsNothing);
      final site = tester.getCenter(find.byGlyph(AppGlyphs.globe)).dx;
      final bot = tester.getCenter(find.byGlyph(AppGlyphs.send)).dx;
      final page = tester.getCenter(find.byGlyph(AppGlyphs.link)).dx;
      final support = tester.getCenter(find.byGlyph(AppGlyphs.support)).dx;
      expect(site, lessThan(bot));
      expect(bot, lessThan(page));
      expect(page, lessThan(support));
      expect(tester.takeException(), isNull);
    }
  });

  test('the site button opens account-url, subscription the web page', () {
    final source = File(
      'lib/views/dashboard/widgets/profiles.dart',
    ).readAsStringSync();
    expect(source, contains('final siteUrl = profile?.headers.accountUrl;'));
    expect(
      source,
      contains('final subscriptionPageUrl = profile?.headers.webPageUrl;'),
    );
  });

  testWidgets('an empty or invalid account or bot link hides its button', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {'account-url': ' ', 'bot-url': 'not a link'},
      ),
    ]);
    await pumpCard(tester);

    expect(find.byTooltip('Website'), findsNothing);
    expect(find.byTooltip('Bot'), findsNothing);
  });

  testWidgets('the header keeps support and update, drawn larger, and no '
      'link to the profiles page', (tester) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {'support-url': 'https://help.example.com'},
      ),
    ]);
    await pumpCard(tester);
    expect(find.byTooltip('Profiles'), findsNothing);
    for (final glyph in [AppGlyphs.support, AppGlyphs.sync]) {
      final icon = tester.widget<GlyphIcon>(find.byGlyph(glyph));
      expect(icon.size, greaterThan(DashboardIconButton.glyphSize));
    }
  });

  testWidgets('the dense header packs its links tightly beside the name', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1, type: ProfileType.url).copyWith(
        providerHeaders: const {
          'account-url': 'https://site.example.com',
          'bot-url': 'https://t.me/example_bot',
          'profile-web-page-url': 'https://sub.example.com',
          'support-url': 'https://help.example.com',
        },
      ),
    ]);
    await pumpCard(tester, card: const ProfilesCard(dense: true));
    for (final key in ['profile-site', 'profile-bot', 'profile-more']) {
      expect(tester.getSize(find.byKey(ValueKey(key))).width, 28);
    }
    final site = tester.getRect(find.byKey(const ValueKey('profile-site')));
    final bot = tester.getRect(find.byKey(const ValueKey('profile-bot')));
    expect(bot.left - site.right, 0);
    expect(tester.takeException(), isNull);
  });

  test('the link glyphs share one centre line', () {
    for (final glyph in [
      AppGlyphs.globe,
      AppGlyphs.send,
      AppGlyphs.link,
      AppGlyphs.support,
    ]) {
      final bounds = glyph.shapes
          .map((shape) => shape.path.getBounds())
          .reduce((a, b) => a.expandToInclude(b));
      expect(bounds.center.dy, closeTo(12, 0.4));
    }
  });

  testWidgets('a successful update shows a green check for a second', (
    tester,
  ) async {
    setUpProfiles(
      [_profile(1, type: ProfileType.url)],
      overrides: [
        profilesActionProvider.overrideWith(_QuietProfilesAction.new),
      ],
    );
    await pumpCard(tester);
    expect(find.byGlyph(AppGlyphs.sync), findsOneWidget);

    await tester.tap(find.byTooltip('Update'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byGlyph(AppGlyphs.check), findsOneWidget);
    expect(find.byGlyph(AppGlyphs.sync), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byGlyph(AppGlyphs.check), findsNothing);
    expect(find.byGlyph(AppGlyphs.sync), findsOneWidget);
  });

  testWidgets('an update finishing after a switch shows no check on the next '
      'profile', (tester) async {
    _GatedProfilesAction.gate = Completer<void>();
    addTearDown(() => _GatedProfilesAction.gate = null);
    setUpProfiles(
      [_profile(1, type: ProfileType.url), _profile(2, type: ProfileType.url)],
      overrides: [
        profilesActionProvider.overrideWith(_GatedProfilesAction.new),
      ],
    );
    await pumpCard(tester);

    await tester.tap(find.byTooltip('Update'));
    await tester.pump();
    container.read(currentProfileIdProvider.notifier).value = 2;
    await tester.pumpAndSettle();
    _GatedProfilesAction.gate!.complete();
    await tester.pumpAndSettle();

    expect(label('P2'), findsOneWidget);
    expect(find.byGlyph(AppGlyphs.check), findsNothing);
    expect(find.byGlyph(AppGlyphs.sync), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without a support page there is no such button', (tester) async {
    setUpProfiles([_profile(1, type: ProfileType.url)]);
    await pumpCard(tester);
    expect(find.byTooltip('Support'), findsNothing);
    expect(find.byTooltip('Update'), findsOneWidget);
  });

  testWidgets('shows the current profile, what is left of its plan and when '
      'it ends', (tester) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
      _profile(2),
    ]);
    await pumpCard(tester);

    expect(label('P1'), findsOneWidget);
    expect(label('P2'), findsNothing);
    expect(find.text('58 GB'), findsOneWidget);
    expect(find.text('left of 100 GB'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    String two(int value) => value.toString().padLeft(2, '0');
    expect(
      find.text('until ${two(expiry.day)}-${two(expiry.month)}-${expiry.year}'),
      findsOneWidget,
    );
    expect(find.textContaining('%', findRichText: true), findsNothing);
    expect(find.text('Proxy group'), findsNothing);
  });

  testWidgets('offers the panel links to renew and to buy traffic', (
    tester,
  ) async {
    setUpProfiles([
      _profile(1).copyWith(
        providerHeaders: const {
          'flclashx-buyplan': 'https://pay.example.com/plan',
          'flclashx-buytraffic': 'https://pay.example.com/traffic,10',
        },
      ),
    ]);
    await pumpCard(tester);

    expect(find.text('Renew subscription'), findsOneWidget);
    expect(find.text('Buy traffic'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    // An update that no longer carries the header takes the button away.
    container
        .read(profilesProvider.notifier)
        .updateProfile(1, (profile) => profile.copyWith(providerHeaders: {}));
    await tester.pump();

    expect(find.text('Renew subscription'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  Profile endingIn(Duration left) => _profile(
    1,
    info: SubscriptionInfo(
      total: 100 * _gib,
      expire: DateTime.now().add(left).millisecondsSinceEpoch ~/ 1000,
    ),
  );

  for (final (left, shown) in [
    (const Duration(hours: 5, minutes: 30), '5 hours'),
    (const Duration(minutes: 40, seconds: 30), '40 minutes'),
    (const Duration(seconds: 20), '1 minute'),
  ]) {
    testWidgets('a plan ending in $left counts down as $shown', (tester) async {
      setUpProfiles([endingIn(left)]);
      await pumpCard(tester);

      expect(find.text(shown), findsOneWidget);
      expect(find.text('100 GB'), findsOneWidget);
    });
  }

  testWidgets('a plan running out while shown turns to expired', (
    tester,
  ) async {
    setUpProfiles([endingIn(const Duration(seconds: 2))]);
    await pumpCard(tester);
    expect(find.text('1 minute'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2500)),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('1 minute'), findsNothing);
  });

  testWidgets('the desktop card shows the plan figures without an update '
      'time', (tester) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    ]);
    await pumpDesktopCard(tester);

    expect(label('P1'), findsOneWidget);
    expect(find.textContaining('Updated'), findsNothing);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('58 GB'), findsOneWidget);
    expect(find.byTooltip('Update'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a desktop card without a quota shows no plan figures', (
    tester,
  ) async {
    setUpProfiles([_profile(1)]);
    await pumpDesktopCard(tester);

    expect(find.text('No expiry'), findsNothing);
    expect(find.text('Unlimited'), findsNothing);
    expect(find.text('Local'), findsNothing);
    expect(find.text('Rules'), findsNothing);
    expect(find.byTooltip('Update'), findsNothing);
    expect(find.byTooltip('Switch profile'), findsNothing);
  });

  testWidgets('the button beside the name switches the profile in a sheet', (
    tester,
  ) async {
    setUpProfiles([for (var id = 1; id <= 3; id++) _profile(id)]);
    await pumpDesktopCard(tester);

    expect(label('P1'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilesView), findsOneWidget);
    await tester.tap(label('P3').last);
    await tester.pumpAndSettle();

    expect(container.read(currentProfileIdProvider), 3);
    expect(find.byType(ProfileDetailSheet), findsNothing);
  });

  Future<File> writeAppliedConfig(WidgetTester tester) async {
    final file = await tester.runAsync(() async {
      final file = File(await appPath.configFilePath);
      await file.writeAsString(
        'proxies:\n'
        '  - {name: a, type: ss}\n'
        '  - {name: b, type: ss}\n'
        'proxy-groups:\n'
        '  - {name: g, type: select, proxies: [a]}\n'
        'rules:\n'
        '  - MATCH,DIRECT\n'
        '  - DOMAIN,a.com,DIRECT\n'
        '  - GEOIP,CN,DIRECT\n',
      );
      return file;
    });
    addTearDown(() async {
      if (file!.existsSync()) file.deleteSync();
    });
    return file!;
  }

  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(label('P1'));
    await tester.pumpAndSettle();
    await settleCounts(tester, until: find.text('3'));
    await tester.pumpAndSettle();
  }

  testWidgets('reopening on the same config skips the read', (tester) async {
    final config = await writeAppliedConfig(tester);
    globalState.lastConfigMd5 = 'applied';
    addTearDown(() => globalState.lastConfigMd5 = null);
    setUpProfiles([_profile(1)]);
    container.listen(groupsProvider, (_, _) {});
    await pumpCard(tester);

    await openDetail(tester);
    config.deleteSync();
    container.read(groupsProvider.notifier).value = [
      const Group(type: GroupType.Selector, name: 'G1'),
    ];
    await tester.pumpAndSettle();
    globalState.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await openDetail(tester);

    expect(
      find.descendant(
        of: find.byType(ProfileDetailSheet),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a narrow card keeps its figures without an update time', (
    tester,
  ) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    ]);
    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.standard,
        scale: 1,
        child: SizedBox(height: 176, child: ProfilesCard()),
      ),
      width: 600,
    );
    expect(find.textContaining('Updated'), findsNothing);
    expect(find.text('58 GB'), findsOneWidget);

    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.standard,
        scale: 1,
        child: SizedBox(height: 176, child: ProfilesCard()),
      ),
      width: 240,
    );
    expect(find.textContaining('minutes ago'), findsNothing);
    expect(find.text('58 GB'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a compact card keeps the plan figures and leaves the update '
      'time to the details', (tester) async {
    final expiry = DateTime.now().add(const Duration(days: 30, hours: 1));
    setUpProfiles([
      _profile(
        1,
        type: ProfileType.url,
        info: SubscriptionInfo(
          upload: _gib,
          download: 41 * _gib,
          total: 100 * _gib,
          expire: expiry.millisecondsSinceEpoch ~/ 1000,
        ),
      ),
      _profile(2),
    ]);
    await pumpCard(
      tester,
      card: const DashboardDensityScope(
        density: DashboardDensity.compact,
        scale: 1,
        child: SizedBox(height: 152, child: ProfilesCard()),
      ),
      width: 220,
    );

    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('58 GB'), findsOneWidget);
    expect(find.byTooltip('Switch profile'), findsOneWidget);
    expect(find.textContaining('minutes ago'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the card shows what the Core was handed', (
    tester,
  ) async {
    await writeAppliedConfig(tester);
    setUpProfiles(
      [_profile(1), _profile(2)],
      overrides: [
        providersProvider.overrideWithBuild(
          (_, _) => [_provider('nodes', 'Proxy', 5)],
        ),
      ],
    );
    container.read(currentProfileIdProvider.notifier).value = 1;
    await pumpCard(tester);

    await openDetail(tester);

    expect(find.byType(ProfileDetailSheet), findsOneWidget);
    expect(find.byTooltip('Runtime config'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ExternalProvidersSliver),
        matching: find.byType(ProviderItem),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Update'), findsOneWidget);
    for (final (title, value) in [
      ('Proxy group', '1'),
      ('Proxies', '7'),
      ('Rules', '3'),
    ]) {
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Column))
              .first,
          matching: find.text(value),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the simple mode leaves the external resources and the extend '
      'mode out of the sheet', (tester) async {
    await writeAppliedConfig(tester);
    setUpProfiles(
      [_profile(1)],
      overrides: [
        providersProvider.overrideWithBuild(
          (_, _) => [_provider('nodes', 'Proxy', 5)],
        ),
        simpleModeProvider.overrideWithValue(true),
      ],
    );
    container.read(currentProfileIdProvider.notifier).value = 1;
    await pumpCard(tester);

    await openDetail(tester);

    expect(find.byType(ProfileDetailSheet), findsOneWidget);
    expect(find.byType(ExternalProvidersSliver), findsNothing);
    expect(find.text('External resources'), findsNothing);
    expect(find.text('Extend mode'), findsNothing);
    expect(find.byTooltip('Runtime config'), findsNothing);
    expect(find.text('Proxies'), findsOneWidget);
  });

  testWidgets('a panel hiding its settings keeps the config out of the sheet', (
    tester,
  ) async {
    await writeAppliedConfig(tester);
    setUpProfiles(
      [
        _profile(1).copyWith(providerHeaders: const {'hide-settings': '1'}),
      ],
      overrides: [
        providersProvider.overrideWithBuild(
          (_, _) => [_provider('nodes', 'Proxy', 5)],
        ),
      ],
    );
    container.read(currentProfileIdProvider.notifier).value = 1;
    await pumpCard(tester);

    await openDetail(tester);

    expect(find.byType(ProfileDetailSheet), findsOneWidget);
    expect(find.byTooltip('Runtime config'), findsNothing);
    expect(find.byType(ExternalProvidersSliver), findsNothing);
    expect(find.text('Extend mode'), findsNothing);
    expect(find.text('Proxies'), findsOneWidget);
  });

  testWidgets('tapping a custom profile edits it in a sheet, built as it '
      'opens', (tester) async {
    final profile = Profile.custom(label: 'mine');
    setUpProfiles(
      [profile],
      overrides: [
        profileRulesProvider.overrideWith2((_) => _TestProfileRules()),
        proxyGroupsProvider.overrideWith2((_) => _TestProxyGroups()),
        customProfileDataProvider(
          profile.id,
        ).overrideWithValue(const CustomProfileData(ruleTargets: {'DIRECT'})),
        setupActionProvider.overrideWith(_IdleSetupAction.new),
      ],
    );
    await pumpCard(tester);

    await tester.tap(label('mine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CustomProfileView), findsOneWidget);
    expect(
      find.byKey(const ValueKey(NullStatusIllustration.profile)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(CustomProfileView),
        matching: find.byType(CommonCard),
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(find.byType(NullStatus), findsOneWidget);
    expect(find.byType(ProfileDetailSheet), findsNothing);
    final sheet = find.byType(NestedPagedSheet);
    expect(
      find.descendant(of: sheet, matching: find.byType(CustomProfileView)),
      findsOneWidget,
    );

    await tester.tap(
      find.ancestor(of: find.text('Rule'), matching: find.byType(CommonCard)),
    );
    await tester.pumpAndSettle();

    expect(
      ModalRoute.of(tester.element(find.byType(CustomRulesView))),
      isA<PagedSheetRoute<void>>(),
    );
  });

  testWidgets('the dense card deletes its profile once confirmed', (
    tester,
  ) async {
    _DeletingProfilesAction.deleted.clear();
    setUpProfiles(
      [_profile(1, type: ProfileType.url)],
      overrides: [
        profilesActionProvider.overrideWith(_DeletingProfilesAction.new),
      ],
    );
    await pumpCard(tester, card: const ProfilesCard(dense: true));

    await tester.tap(find.byKey(const ValueKey('profile-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    final dialog = find.byType(CommonDialog);
    for (var i = 0; i < 20 && dialog.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(dialog, findsOneWidget);
    expect(_DeletingProfilesAction.deleted, isEmpty);

    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Delete')),
    );
    for (var i = 0; i < 20 && _DeletingProfilesAction.deleted.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_DeletingProfilesAction.deleted, [1]);
  });

  testWidgets('the dense card shows its footer rows under the plan', (
    tester,
  ) async {
    setUpProfiles([_profile(1, type: ProfileType.url)]);
    await pumpCard(
      tester,
      card: const ProfilesCard(
        dense: true,
        footer: [Text('Promo row', key: ValueKey('footer-promo'))],
      ),
    );
    final card = tester.getRect(
      find.byKey(const ValueKey('profile-card-dense')),
    );
    final promo = tester.getRect(find.byKey(const ValueKey('footer-promo')));
    expect(card.contains(promo.center), isTrue);
    expect(
      promo.top,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('profile-card-name'))).bottom,
      ),
    );
  });

  test('counts provider proxies but not provider rules', () {
    final stats = profileStatsOf(
      configCountsOf({
        'proxies': [{}],
        'proxy-groups': [{}, {}],
        'rules': ['MATCH,DIRECT'],
      }),
      [_provider('nodes', 'Proxy', 4), _provider('ads', 'Rule', 900)],
    );

    expect(stats, (groups: 2, proxies: 5, rules: 1, providers: 2));
  });
}

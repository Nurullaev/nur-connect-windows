import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/split_tunnel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

TrackerInfo _connection(String id, String process) => TrackerInfo(
  id: id,
  start: DateTime.utc(2026),
  metadata: Metadata(network: 'tcp', host: 'example.com', process: process),
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    SplitTunnelProps props = const SplitTunnelProps(),
    List<TrackerInfo> connections = const [],
  }) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        networkSettingProvider.overrideWithBuild(
          (_, _) => NetworkProps(splitTunnel: props),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          child: SplitTunnelView(connectionsReader: () async => connections),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  SplitTunnelProps read(ProviderContainer container) =>
      container.read(networkSettingProvider).splitTunnel;

  testWidgets('the switch turns the split tunnel on', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('split-tunnel-enabled')));
    await tester.pump();
    expect(read(container).enabled, isTrue);
    expect(
      find.text(
        'Add programs. While the list is empty, all traffic goes as usual.',
      ),
      findsOne,
    );
  });

  testWidgets('active connections offer their programs once', (tester) async {
    final container = await pump(
      tester,
      props: const SplitTunnelProps(enabled: true, apps: ['steam.exe']),
      connections: [
        _connection('1', 'chrome.exe'),
        _connection('2', 'Chrome.exe'),
        _connection('3', 'Steam.exe'),
        _connection('4', ''),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('split-tunnel-add-running')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('split-tunnel-running-chrome.exe')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('split-tunnel-running-Steam.exe')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('split-tunnel-running-chrome.exe')),
    );
    await tester.pumpAndSettle();
    expect(read(container).apps, ['steam.exe', 'chrome.exe']);
    expect(find.byKey(const ValueKey('split-tunnel-app-chrome.exe')), findsOne);
  });

  testWidgets('a program leaves the list with its delete button', (
    tester,
  ) async {
    final container = await pump(
      tester,
      props: const SplitTunnelProps(
        enabled: true,
        mode: SplitTunnelMode.exceptSelected,
        apps: ['steam.exe', 'chrome.exe'],
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('split-tunnel-app-steam.exe')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pump();
    expect(read(container).apps, ['chrome.exe']);
    expect(read(container).mode, SplitTunnelMode.exceptSelected);
  });

  testWidgets('torrent clients bypass the VPN until switched off', (
    tester,
  ) async {
    final container = await pump(tester);
    final toggle = find.byKey(const ValueKey('split-tunnel-torrent-direct'));
    expect(toggle, findsOne);
    expect(find.text('Torrent clients bypass the VPN'), findsOne);
    expect(read(container).torrentDirect, isTrue);

    await tester.tap(toggle);
    await tester.pump();
    expect(read(container).torrentDirect, isFalse);
    // The split tunnel's own switch stays as it was.
    expect(read(container).enabled, isFalse);
  });

  testWidgets('the settings entry tells torrents go around the VPN', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        networkSettingProvider.overrideWithBuild(
          (_, _) => const NetworkProps(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          child: Scaffold(body: SplitTunnelItem()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Torrents bypass the VPN'), findsOne);

    container
        .read(networkSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            splitTunnel: state.splitTunnel.copyWith(torrentDirect: false),
          ),
        );
    await tester.pump();
    expect(find.text('Off'), findsOne);

    // Riverpod disposes the watched provider on a timer: let it run.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Nur home is shared by Windows and macOS', () {
    expect(nurDesktopLayout(SupportPlatform.Windows), isTrue);
    expect(nurDesktopLayout(SupportPlatform.MacOS), isTrue);
    expect(nurDesktopLayout(SupportPlatform.Android), isFalse);
    expect(nurDesktopLayout(SupportPlatform.Linux), isFalse);
  });

  test('macOS process rules do not carry Windows executable names', () {
    final rules = torrentDirectRulesFor(SupportPlatform.MacOS);
    expect(rules, contains('PROCESS-NAME,Transmission,DIRECT'));
    expect(rules, contains('PROCESS-NAME,uTorrent Neo,DIRECT'));
    expect(rules, contains('PROCESS-NAME,qbittorrent,DIRECT'));
    expect(rules.join('\n'), isNot(contains('.exe')));
    expect(rules.join('\n'), isNot(contains('java')));
    expect(torrentDirectRulesFor(SupportPlatform.Windows), hasLength(32));
  });

  test(
    'Finder package resolves CFBundleExecutable rather than display name',
    () async {
      final root = Directory.systemTemp.createTempSync('nur-macos-picker-');
      addTearDown(() => root.deleteSync(recursive: true));
      final bundle = p.join(root.path, 'Friendly browser.app');
      final executable = File(
        p.join(bundle, 'Contents', 'MacOS', 'Real Browser'),
      );
      executable.createSync(recursive: true);
      final plist = File(p.join(bundle, 'Contents', 'Info.plist'));
      plist.writeAsStringSync(
        '<?xml version="1.0"?><plist version="1.0"><dict>'
        '<key>CFBundleExecutable</key><string>Real Browser</string>'
        '</dict></plist>',
      );
      expect(await splitTunnelExecutable(bundle), 'Real Browser');
      executable.deleteSync();
      expect(await splitTunnelExecutable(bundle), isNull);
      plist.writeAsStringSync(
        '<?xml version="1.0"?><plist version="1.0"><dict>'
        '<key>CFBundleExecutable</key><string>../outside</string>'
        '</dict></plist>',
      );
      expect(await splitTunnelExecutable(bundle), isNull);
    },
    skip: !Platform.isMacOS,
  );
}

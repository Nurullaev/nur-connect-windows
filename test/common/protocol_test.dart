import 'package:fl_clash/common/protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Windows owns only its channel scheme while accepting older imports',
    () {
      expect(windowsRegisteredSchemes(pre: false), ['nurconnect-win']);
      expect(windowsRegisteredSchemes(pre: true), ['nurconnect-win-pre']);
      expect(
        protocolSchemes,
        containsAll(['nurconnect-win', 'flclashx', 'clash']),
      );
      expect(windowsRegisteredSchemes(pre: false), isNot(contains('flclashx')));
      expect(
        windowsRegisteredSchemes(pre: true),
        isNot(contains('nurconnect-win')),
      );
    },
  );

  group('ProtocolRegistrationPlan', () {
    test('builds registry writes for URL protocol registration', () {
      const plan = ProtocolRegistrationPlan(
        scheme: 'flclash',
        executable: r'C:\Program Files\FlClash\FlClash.exe',
      );

      expect(plan.protocolKey, r'Software\Classes\flclash');
      expect(plan.commandKey, r'shell\open\command');
      expect(plan.protocolValueName, 'URL Protocol');
      expect(plan.protocolValue, '');
      expect(plan.command, r'"C:\Program Files\FlClash\FlClash.exe" "%1"');
    });
  });

  group('registerProtocolPlan', () {
    const plan = ProtocolRegistrationPlan(
      scheme: 'nurconnect-win',
      executable: r'C:\Program Files\Nur Connect\NurConnect.exe',
    );

    test('leaves a scheme that already points at the app alone', () {
      final registry = _FakeRegistry(
        marker: '',
        command: r'"C:\Program Files\Nur Connect\NurConnect.exe" "%1"',
      );
      expect(registerProtocolPlan(plan, registry), isTrue);
      expect(registry.writes, 0);
    });

    test('writes a missing or stale scheme', () {
      final missing = _FakeRegistry();
      expect(registerProtocolPlan(plan, missing), isTrue);
      expect(missing.writes, 1);

      final stale = _FakeRegistry(
        marker: '',
        command: r'"D:\Old\NurConnect.exe" "%1"',
      );
      expect(registerProtocolPlan(plan, stale), isTrue);
      expect(stale.writes, 1);
    });

    test('a refused write lets the app start without the link handler', () {
      // An antivirus guarding protocol keys answers 0x80070005.
      final registry = _FakeRegistry(refuseWrite: true);
      expect(registerProtocolPlan(plan, registry), isFalse);
      expect(registry.writes, 1);
    });

    test('an unreadable key still gets the write', () {
      final registry = _FakeRegistry(refuseRead: true);
      expect(registerProtocolPlan(plan, registry), isTrue);
      expect(registry.writes, 1);
    });
  });

  group('LinuxProtocolRegistrationPlan', () {
    const plan = LinuxProtocolRegistrationPlan(
      schemes: legacyProtocolSchemes,
      executable: '/home/me/Apps/FlClash.AppImage',
      applicationsDir: '/home/me/.local/share/applications',
    );

    test('writes a hidden desktop entry claiming every scheme', () {
      expect(
        plan.desktopPath,
        '/home/me/.local/share/applications/flclash-url-handler.desktop',
      );
      expect(
        plan.desktopEntry,
        '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=FlClash\n'
        'NoDisplay=true\n'
        'Exec="/home/me/Apps/FlClash.AppImage" %u\n'
        'MimeType=x-scheme-handler/clash;x-scheme-handler/clashmeta;'
        'x-scheme-handler/flclash;x-scheme-handler/flclashx;'
        'x-scheme-handler/clashx;\n',
      );
    });

    test('makes the entry the default handler for every scheme', () {
      expect(plan.xdgMimeArguments, [
        'default',
        'flclash-url-handler.desktop',
        'x-scheme-handler/clash',
        'x-scheme-handler/clashmeta',
        'x-scheme-handler/flclash',
        'x-scheme-handler/flclashx',
        'x-scheme-handler/clashx',
      ]);
    });

    test('escapes reserved characters in the executable path', () {
      const plan = LinuxProtocolRegistrationPlan(
        schemes: ['flclash'],
        executable: r'/opt/my "apps"/$HOME/100%/Fl`Clash\bin',
        applicationsDir: '/tmp',
      );

      expect(plan.exec, r'"/opt/my \"apps\"/\$HOME/100%%/Fl\`Clash\\bin" %u');
    });
  });
}

class _FakeRegistry implements ProtocolRegistry {
  _FakeRegistry({
    this.marker,
    this.command,
    this.refuseRead = false,
    this.refuseWrite = false,
  });

  final String? marker;
  final String? command;
  final bool refuseRead;
  final bool refuseWrite;
  int writes = 0;

  @override
  ({String? marker, String? command}) read(ProtocolRegistrationPlan plan) {
    if (refuseRead) throw StateError('access denied');
    return (marker: marker, command: command);
  }

  @override
  void write(ProtocolRegistrationPlan plan) {
    writes++;
    if (refuseWrite) throw StateError('HRESULT(0x80070005)');
  }
}

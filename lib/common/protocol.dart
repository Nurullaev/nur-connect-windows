import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';

import '../enum/enum.dart';
import 'print.dart';
import 'product_identity.dart';

const legacyProtocolSchemes = [
  'clash',
  'clashmeta',
  'flclash',
  'flclashx',
  'clashx',
];
const protocolSchemes = [
  windowsProtocolScheme,
  windowsPreProtocolScheme,
  ...legacyProtocolSchemes,
];

// Accept older import links, but register only our own Windows handler.
List<String> windowsRegisteredSchemes({required bool pre}) => [
  pre ? windowsPreProtocolScheme : windowsProtocolScheme,
];

class ProtocolRegistrationPlan {
  final String scheme;
  final String executable;

  const ProtocolRegistrationPlan({
    required this.scheme,
    required this.executable,
  });

  String get protocolKey => 'Software\\Classes\\$scheme';

  String get commandKey => 'shell\\open\\command';

  String get protocolValueName => 'URL Protocol';

  String get protocolValue => '';

  String get command => '"$executable" "%1"';
}

/// The current user's registry as the link registration sees it, so tests can
/// stand in for it.
abstract interface class ProtocolRegistry {
  /// The `URL Protocol` marker and the open command now stored for [plan]'s
  /// scheme, each null when missing.
  ({String? marker, String? command}) read(ProtocolRegistrationPlan plan);

  /// Points [plan]'s scheme at its executable.
  void write(ProtocolRegistrationPlan plan);
}

class WindowsProtocolRegistry implements ProtocolRegistry {
  const WindowsProtocolRegistry();

  @override
  ({String? marker, String? command}) read(ProtocolRegistrationPlan plan) {
    final key = CURRENT_USER.open(plan.protocolKey);
    try {
      return (
        marker: key.getString(plan.protocolValueName),
        command: key.getString('', path: plan.commandKey),
      );
    } finally {
      key.close();
    }
  }

  @override
  void write(ProtocolRegistrationPlan plan) {
    final regKey = CURRENT_USER.create(plan.protocolKey);
    try {
      regKey.setValue(
        plan.protocolValueName,
        RegistryValue.string(plan.protocolValue),
      );
      final commandKey = regKey.create(plan.commandKey);
      try {
        commandKey.setValue('', RegistryValue.string(plan.command));
      } finally {
        commandKey.close();
      }
    } finally {
      regKey.close();
    }
  }
}

/// Registers [plan]'s scheme unless it already points at the executable, and
/// says whether it does now. The link handler is optional: a refused write,
/// such as an antivirus guarding protocol keys from an unsigned app, is logged
/// and the app starts without it.
@visibleForTesting
bool registerProtocolPlan(
  ProtocolRegistrationPlan plan,
  ProtocolRegistry registry,
) {
  try {
    final current = registry.read(plan);
    if (current.marker == plan.protocolValue &&
        current.command == plan.command) {
      return true;
    }
  } catch (_) {
    // Missing or unreadable alike: the write says what is wrong.
  }
  try {
    registry.write(plan);
    return true;
  } catch (error) {
    commonPrint.log(
      'link scheme ${plan.scheme} not registered: $error',
      logLevel: LogLevel.warning,
    );
    return false;
  }
}

/// A user-level desktop entry that claims the schemes for the running binary,
/// so an AppImage or a development build is reachable without a packaged
/// .desktop file. Rewritten on every launch, like the Windows registry keys.
class LinuxProtocolRegistrationPlan {
  final List<String> schemes;
  final String executable;
  final String applicationsDir;

  const LinuxProtocolRegistrationPlan({
    required this.schemes,
    required this.executable,
    required this.applicationsDir,
  });

  String get desktopId => 'flclash-url-handler.desktop';

  String get desktopPath => '$applicationsDir/$desktopId';

  List<String> get mimeTypes =>
      schemes.map((scheme) => 'x-scheme-handler/$scheme').toList();

  String get exec => '"${_quoteExecArgument(executable)}" %u';

  String get desktopEntry => [
    '[Desktop Entry]',
    'Type=Application',
    'Name=FlClash',
    'NoDisplay=true',
    'Exec=$exec',
    'MimeType=${mimeTypes.join(';')};',
    '',
  ].join('\n');

  List<String> get xdgMimeArguments => ['default', desktopId, ...mimeTypes];

  static String _quoteExecArgument(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`')
        .replaceAll('%', '%%');
  }
}

class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  /// Never throws: see [registerProtocolPlan].
  bool register(String scheme) => registerProtocolPlan(
    ProtocolRegistrationPlan(
      scheme: scheme,
      executable: Platform.resolvedExecutable,
    ),
    const WindowsProtocolRegistry(),
  );

  Future<void> registerLinux(List<String> schemes) async {
    final env = Platform.environment;
    final home = env['HOME'];
    if (home == null || home.isEmpty) {
      return;
    }
    final dataHome = env['XDG_DATA_HOME'];
    final plan = LinuxProtocolRegistrationPlan(
      schemes: schemes,
      executable: env['APPIMAGE'] ?? Platform.resolvedExecutable,
      applicationsDir:
          '${dataHome?.isNotEmpty == true ? dataHome : '$home/.local/share'}/applications',
    );
    try {
      final file = File(plan.desktopPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(plan.desktopEntry);
      final result = await Process.run('xdg-mime', plan.xdgMimeArguments);
      if (result.exitCode != 0) {
        commonPrint.log('xdg-mime default failed: ${result.stderr}'.trim());
      }
    } catch (e) {
      commonPrint.log('linux protocol registration failed: $e');
    }
  }
}

final protocol = Protocol();

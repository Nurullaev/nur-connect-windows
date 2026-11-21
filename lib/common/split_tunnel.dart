import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// What a rule line or a Windows file name cannot carry.
final _unsafe = RegExp(r'[,()\\/:*?"<>|\x00-\x1f]');

final _separators = RegExp(r'[\\/]');

/// The file name a split tunnel matches, from a path or a typed name, or null
/// when nothing a rule can carry is left.
String? splitTunnelAppName(String input) {
  final name = input.trim().split(_separators).last.trim();
  if (name.isEmpty ||
      name.length > 255 ||
      name == '.' ||
      name == '..' ||
      _unsafe.hasMatch(name)) {
    return null;
  }
  return name;
}

/// The programs [props] names, each once: Windows file names ignore case.
List<String> splitTunnelApps(SplitTunnelProps props) {
  final seen = <String>{};
  return [
    for (final raw in props.apps)
      if (splitTunnelAppName(raw) case final name?
          when seen.add(name.toLowerCase()))
        name,
  ];
}

/// Direct routing sends nothing through the VPN, so there is nothing to split.
bool splitTunnelActive(SplitTunnelProps props, Mode mode) =>
    props.enabled && mode != Mode.direct && splitTunnelApps(props).isNotEmpty;

/// Global routing ignores rules, so a split tunnel runs the Core on rule
/// routing that ends on GLOBAL, where the picked server stays.
Mode splitTunnelCoreMode(SplitTunnelProps props, Mode mode) =>
    mode == Mode.global && splitTunnelActive(props, mode) ? Mode.rule : mode;

/// The rules a split tunnel puts before the profile's own, or in their place
/// under global routing. The Core matches process names ignoring case.
({List<String> rules, bool replace}) splitTunnelRules(
  SplitTunnelProps props,
  Mode mode,
) {
  if (!splitTunnelActive(props, mode)) {
    return (rules: const <String>[], replace: false);
  }
  final apps = splitTunnelApps(props);
  final head = switch (props.mode) {
    SplitTunnelMode.onlySelected => [
      apps.length == 1
          ? 'NOT,((PROCESS-NAME,${apps.single})),DIRECT'
          : 'NOT,((OR,(${apps.map((app) => '(PROCESS-NAME,$app)').join(',')}))),DIRECT',
    ],
    SplitTunnelMode.exceptSelected => [
      for (final app in apps) 'PROCESS-NAME,$app,DIRECT',
    ],
  };
  final replace = mode == Mode.global;
  return (
    rules: [...head, if (replace) 'MATCH,${GroupName.GLOBAL.name}'],
    replace: replace,
  );
}

/// Changes whenever the split tunnel's rules would: empty while it is off.
String splitTunnelKey(SplitTunnelProps props, Mode mode) {
  final (:rules, :replace) = splitTunnelRules(props, mode);
  return rules.isEmpty ? '' : '${replace ? 1 : 0}\n${rules.join('\n')}';
}

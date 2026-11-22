import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// What a rule line or a Windows file name cannot carry.
final _unsafe = RegExp(r'[,()\\/:*?"<>|\x00-\x1f]');

final _separators = RegExp(r'[\\/]');

/// Torrent clients for Windows that skip the VPN while
/// [SplitTunnelProps.torrentDirect] is on, so their traffic leaves the nodes
/// alone. The Core matches process names ignoring case. Zona downloads
/// through its own bundled Java, which a process name would confuse with
/// every other Java program, so its path is matched instead.
const torrentDirectRules = [
  'PROCESS-NAME,uTorrent.exe,DIRECT',
  'PROCESS-NAME,utorrentie.exe,DIRECT',
  'PROCESS-NAME,utweb.exe,DIRECT',
  'PROCESS-NAME,BitTorrent.exe,DIRECT',
  'PROCESS-NAME,bittorrentie.exe,DIRECT',
  'PROCESS-NAME,btweb.exe,DIRECT',
  'PROCESS-NAME,qbittorrent.exe,DIRECT',
  'PROCESS-NAME,transmission-qt.exe,DIRECT',
  'PROCESS-NAME,transmission-daemon.exe,DIRECT',
  'PROCESS-NAME,deluge.exe,DIRECT',
  'PROCESS-NAME,deluged.exe,DIRECT',
  'PROCESS-NAME,deluge-debug.exe,DIRECT',
  'PROCESS-NAME,deluged-debug.exe,DIRECT',
  'PROCESS-NAME,BitComet.exe,DIRECT',
  'PROCESS-NAME,BitComet_x64.exe,DIRECT',
  'PROCESS-NAME,tixati.exe,DIRECT',
  'PROCESS-NAME,PicoTorrent.exe,DIRECT',
  'PROCESS-NAME,BitLord.exe,DIRECT',
  'PROCESS-NAME,BiglyBT.exe,DIRECT',
  'PROCESS-NAME,Azureus.exe,DIRECT',
  'PROCESS-NAME,FrostWire.exe,DIRECT',
  'PROCESS-NAME,Tribler.exe,DIRECT',
  'PROCESS-NAME,WebTorrent.exe,DIRECT',
  'PROCESS-NAME,mediaget.exe,DIRECT',
  'PROCESS-NAME,uFiler.exe,DIRECT',
  'PROCESS-NAME,ace_engine.exe,DIRECT',
  'PROCESS-NAME,TorrServer-windows-amd64.exe,DIRECT',
  'PROCESS-NAME,TorrServer-windows-386.exe,DIRECT',
  'PROCESS-NAME,TorrServer-windows-arm64.exe,DIRECT',
  'PROCESS-NAME,TorrServer.exe,DIRECT',
  'PROCESS-NAME,Zona.exe,DIRECT',
  r'PROCESS-PATH-WILDCARD,*\Zona\jre\bin\javaw.exe,DIRECT',
];

/// macOS process names are the executables inside .app bundles, not .exe files.
const macosTorrentDirectRules = [
  'PROCESS-NAME,uTorrent,DIRECT',
  'PROCESS-NAME,uTorrent Neo,DIRECT',
  'PROCESS-NAME,utweb,DIRECT',
  'PROCESS-NAME,BitTorrent,DIRECT',
  'PROCESS-NAME,btweb,DIRECT',
  'PROCESS-NAME,qbittorrent,DIRECT',
  'PROCESS-NAME,Transmission,DIRECT',
  'PROCESS-NAME,transmission-daemon,DIRECT',
  'PROCESS-NAME,deluge,DIRECT',
  'PROCESS-NAME,deluged,DIRECT',
  'PROCESS-NAME,WebTorrent,DIRECT',
  'PROCESS-NAME,BiglyBT,DIRECT',
  'PROCESS-NAME,TorrServer,DIRECT',
];

List<String> torrentDirectRulesFor(SupportPlatform platform) =>
    platform == SupportPlatform.MacOS
    ? macosTorrentDirectRules
    : torrentDirectRules;

/// A Finder app package names its actual executable in CFBundleExecutable.
/// Never register the bundle's display name as a process rule.
Future<String?> splitTunnelExecutable(String path) async {
  if (!Platform.isMacOS || !path.toLowerCase().endsWith('.app')) {
    return splitTunnelAppName(path);
  }
  final result = await Process.run('/usr/bin/plutil', [
    '-extract',
    'CFBundleExecutable',
    'raw',
    '-o',
    '-',
    '$path/Contents/Info.plist',
  ]);
  if (result.exitCode != 0) return null;
  final raw = (result.stdout as String).trim();
  final name = splitTunnelAppName(raw);
  if (name != raw || !File('$path/Contents/MacOS/$name').existsSync()) {
    return null;
  }
  return name;
}

/// The rule set the provider's subscription carries for sites that work
/// better without the VPN: banks, state services, marketplaces. The provider
/// edits it in the panel; a profile that lacks it gets no rule naming it.
const directSitesProvider = 'direct-sites';

/// Sends the sites in [directSitesProvider] direct while
/// [SplitTunnelProps.directSites] is on.
const directSitesRule = 'RULE-SET,$directSitesProvider,DIRECT';

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

/// Torrent clients go direct unless turned off. With only the picked programs
/// on the VPN everything else, torrents included, is direct already, and a
/// torrent client picked there stays on the VPN as the user asked.
bool torrentDirectActive(SplitTunnelProps props, Mode mode) =>
    props.torrentDirect &&
    mode != Mode.direct &&
    !(splitTunnelActive(props, mode) &&
        props.mode == SplitTunnelMode.onlySelected);

/// Local sites go direct unless turned off, for the programs on the VPN too:
/// a bank refuses a foreign address whichever browser opens it.
bool directSitesActive(SplitTunnelProps props, Mode mode) =>
    props.directSites && mode != Mode.direct;

/// Global routing ignores rules, so a split tunnel, the torrent rules or the
/// local sites run the Core on rule routing that ends on GLOBAL, where the
/// picked server stays.
Mode splitTunnelCoreMode(SplitTunnelProps props, Mode mode) =>
    mode == Mode.global &&
        (splitTunnelActive(props, mode) ||
            torrentDirectActive(props, mode) ||
            directSitesActive(props, mode))
    ? Mode.rule
    : mode;

/// The rules a split tunnel, the torrent clients and the local sites put
/// before the profile's own, or in their place under global routing. The Core
/// matches process names ignoring case. [directSitesRule] stays in the list;
/// building the profile drops it when the subscription lacks its rule set.
({List<String> rules, bool replace}) splitTunnelRules(
  SplitTunnelProps props,
  Mode mode,
) {
  final split = splitTunnelActive(props, mode);
  final torrents = torrentDirectActive(props, mode);
  final sites = directSitesActive(props, mode);
  if (!split && !torrents && !sites) {
    return (rules: const <String>[], replace: false);
  }
  final apps = split ? splitTunnelApps(props) : const <String>[];
  final head = [
    if (split)
      ...switch (props.mode) {
        SplitTunnelMode.onlySelected => [
          apps.length == 1
              ? 'NOT,((PROCESS-NAME,${apps.single})),DIRECT'
              : 'NOT,((OR,(${apps.map((app) => '(PROCESS-NAME,$app)').join(',')}))),DIRECT',
        ],
        SplitTunnelMode.exceptSelected => [
          for (final app in apps) 'PROCESS-NAME,$app,DIRECT',
        ],
      },
    if (torrents) ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
    if (sites) directSitesRule,
  ];
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

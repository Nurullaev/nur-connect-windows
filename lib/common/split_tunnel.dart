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

/// Global routing ignores rules, so a split tunnel or the torrent rules run
/// the Core on rule routing that ends on GLOBAL, where the picked server stays.
Mode splitTunnelCoreMode(SplitTunnelProps props, Mode mode) =>
    mode == Mode.global &&
        (splitTunnelActive(props, mode) || torrentDirectActive(props, mode))
    ? Mode.rule
    : mode;

/// The rules a split tunnel and the torrent clients put before the profile's
/// own, or in their place under global routing. The Core matches process
/// names ignoring case.
({List<String> rules, bool replace}) splitTunnelRules(
  SplitTunnelProps props,
  Mode mode,
) {
  final split = splitTunnelActive(props, mode);
  final torrents = torrentDirectActive(props, mode);
  if (!split && !torrents) {
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
    if (torrents) ...torrentDirectRules,
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

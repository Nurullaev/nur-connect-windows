import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _two = SplitTunnelProps(
  enabled: true,
  apps: ['chrome.exe', 'Telegram.exe'],
);

void main() {
  group('splitTunnelAppName', () {
    test('takes the file name of a Windows path', () {
      expect(
        splitTunnelAppName(r'C:\Program Files\Google\Chrome\chrome.exe'),
        'chrome.exe',
      );
      expect(splitTunnelAppName(' My App 2.exe '), 'My App 2.exe');
    });

    test('refuses what a rule line cannot carry', () {
      for (final bad in [
        '',
        '  ',
        'a,b.exe',
        'a(1).exe',
        'C:\\',
        '..',
        'x|y',
      ]) {
        expect(splitTunnelAppName(bad), isNull, reason: bad);
      }
    });
  });

  test('apps keep their first spelling, once each', () {
    const props = SplitTunnelProps(
      enabled: true,
      apps: ['Chrome.exe', 'chrome.EXE', 'bad,name.exe', 'steam.exe'],
    );
    expect(splitTunnelApps(props), ['Chrome.exe', 'steam.exe']);
  });

  group('splitTunnelRules', () {
    test('off, empty or direct routing adds nothing', () {
      for (final (props, mode) in [
        (
          const SplitTunnelProps(
            apps: ['chrome.exe'],
            torrentDirect: false,
            directSites: false,
          ),
          Mode.global,
        ),
        (
          const SplitTunnelProps(
            enabled: true,
            torrentDirect: false,
            directSites: false,
          ),
          Mode.global,
        ),
        (_two, Mode.direct),
        (const SplitTunnelProps(), Mode.direct),
      ]) {
        final split = splitTunnelRules(props, mode);
        expect(split.rules, isEmpty);
        expect(split.replace, isFalse);
        expect(splitTunnelKey(props, mode), '');
        expect(splitTunnelCoreMode(props, mode), mode);
      }
    });

    test('only selected apps under global routing end on GLOBAL', () {
      final split = splitTunnelRules(_two, Mode.global);
      expect(split.rules, [
        'NOT,((OR,((PROCESS-NAME,chrome.exe),(PROCESS-NAME,Telegram.exe)))),DIRECT',
        directSitesRule,
        'MATCH,GLOBAL',
      ]);
      expect(split.replace, isTrue);
      expect(splitTunnelCoreMode(_two, Mode.global), Mode.rule);
    });

    test('a single selected app needs no OR', () {
      const props = SplitTunnelProps(enabled: true, apps: ['chrome.exe']);
      expect(splitTunnelRules(props, Mode.rule).rules, [
        'NOT,((PROCESS-NAME,chrome.exe)),DIRECT',
        directSitesRule,
      ]);
    });

    test('excepted apps go direct and rule routing keeps its rules', () {
      final props = _two.copyWith(mode: SplitTunnelMode.exceptSelected);
      final split = splitTunnelRules(props, Mode.rule);
      expect(split.rules, [
        'PROCESS-NAME,chrome.exe,DIRECT',
        'PROCESS-NAME,Telegram.exe,DIRECT',
        ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
        directSitesRule,
      ]);
      expect(split.replace, isFalse);
      expect(splitTunnelCoreMode(props, Mode.rule), Mode.rule);
    });

    test('torrents and local sites go direct by default, the split off', () {
      const props = SplitTunnelProps();
      expect(props.torrentDirect, isTrue);
      expect(props.directSites, isTrue);
      final global = splitTunnelRules(props, Mode.global);
      expect(global.rules, [
        ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
        directSitesRule,
        'MATCH,GLOBAL',
      ]);
      expect(global.replace, isTrue);
      expect(splitTunnelCoreMode(props, Mode.global), Mode.rule);
      final rule = splitTunnelRules(props, Mode.rule);
      expect(rule.rules, [
        ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
        directSitesRule,
      ]);
      expect(rule.replace, isFalse);
      expect(splitTunnelKey(props, Mode.global), isNotEmpty);
    });

    test('turned off, torrents leave only the local sites', () {
      const props = SplitTunnelProps(torrentDirect: false);
      expect(splitTunnelRules(props, Mode.global).rules, [
        directSitesRule,
        'MATCH,GLOBAL',
      ]);
      expect(splitTunnelRules(props, Mode.rule).rules, [directSitesRule]);
      expect(splitTunnelCoreMode(props, Mode.global), Mode.rule);
    });

    test('turned off, local sites leave only the torrents', () {
      const props = SplitTunnelProps(directSites: false);
      expect(
        splitTunnelRules(props, Mode.rule).rules,
        torrentDirectRulesFor(SupportPlatform.currentPlatform),
      );
    });

    test('both turned off add nothing', () {
      const props = SplitTunnelProps(torrentDirect: false, directSites: false);
      expect(splitTunnelRules(props, Mode.global).rules, isEmpty);
      expect(splitTunnelCoreMode(props, Mode.global), Mode.global);
      expect(splitTunnelKey(props, Mode.global), '');
    });

    test('only the picked programs on the VPN leaves torrents alone', () {
      // Everything unpicked is direct already; a picked torrent client
      // stays on the VPN as asked. Local sites skip it for picked programs.
      const props = SplitTunnelProps(enabled: true, apps: ['qbittorrent.exe']);
      expect(splitTunnelRules(props, Mode.rule).rules, [
        'NOT,((PROCESS-NAME,qbittorrent.exe)),DIRECT',
        directSitesRule,
      ]);
    });

    test('the local sites rule names the subscription rule set', () {
      expect(directSitesProvider, 'direct-sites');
      expect(directSitesRule, 'RULE-SET,direct-sites,DIRECT');
    });

    test('the torrent list names each approved client once', () {
      expect(torrentDirectRules, hasLength(32));
      final names = torrentDirectRules
          .map((rule) => rule.split(',')[1].toLowerCase())
          .toList();
      expect(names.toSet(), hasLength(names.length));
      for (final rule in torrentDirectRules) {
        expect(rule, endsWith(',DIRECT'));
        expect(rule.split(','), hasLength(3), reason: rule);
      }
      for (final name in [
        'utorrent.exe',
        'qbittorrent.exe',
        'bitcomet_x64.exe',
        'transmission-qt.exe',
        'ace_engine.exe',
        'torrserver-windows-amd64.exe',
      ]) {
        expect(names, contains(name));
      }
      // Download managers carry ordinary downloads too.
      for (final name in ['fdm.exe', 'idman.exe', 'motrix.exe', 'aria2c.exe']) {
        expect(names, isNot(contains(name)));
      }
      expect(
        torrentDirectRules.last,
        r'PROCESS-PATH-WILDCARD,*\Zona\jre\bin\javaw.exe,DIRECT',
      );
    });

    test('the key follows the routing mode', () {
      expect(
        splitTunnelKey(_two, Mode.global),
        isNot(splitTunnelKey(_two, Mode.rule)),
      );
    });
  });

  test('props read back from JSON, an unknown mode falling back', () {
    final json = jsonDecode(
      jsonEncode(const NetworkProps(splitTunnel: _two)),
    ) as Map<String, Object?>;
    expect(NetworkProps.fromJson(json).splitTunnel, _two);
    expect(
      SplitTunnelProps.fromJson({'enabled': true, 'mode': 'later', 'apps': []})
          .mode,
      SplitTunnelMode.onlySelected,
    );
    expect(NetworkProps.fromJson({}).splitTunnel, const SplitTunnelProps());
    // Settings saved before 1.0.7 have no key: torrents go direct after it.
    expect(
      SplitTunnelProps.fromJson({
        'enabled': true,
        'mode': 'exceptSelected',
        'apps': ['steam.exe'],
      }).torrentDirect,
      isTrue,
    );
    final off = jsonDecode(
      jsonEncode(const SplitTunnelProps(torrentDirect: false)),
    ) as Map<String, Object?>;
    expect(SplitTunnelProps.fromJson(off).torrentDirect, isFalse);
    // Settings saved before the local sites switch have no key: on after it.
    expect(
      SplitTunnelProps.fromJson({'torrentDirect': false}).directSites,
      isTrue,
    );
    final sitesOff = jsonDecode(
      jsonEncode(const SplitTunnelProps(directSites: false)),
    ) as Map<String, Object?>;
    expect(SplitTunnelProps.fromJson(sitesOff).directSites, isFalse);
  });

  group('makeRealProfileTask', () {
    Future<MakeRealProfileState> state({bool sites = false}) async =>
        MakeRealProfileState(
          profilesPath: '/profiles',
          profileId: 7,
          rawConfig: await decodeJSONTask<Map<String, dynamic>>(
            jsonEncode({
              'proxies': [],
              if (sites)
                'rule-providers': {
                  'direct-sites': {
                    'type': 'inline',
                    'behavior': 'domain',
                    'payload': ['+.vk.com'],
                  },
                },
              'rules': ['DOMAIN,existing.example,DIRECT', 'MATCH,Servers'],
            }),
          ),
          realPatchConfig: const PatchClashConfig(),
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash-Test',
        );

    test('without a split tunnel the YAML is unchanged', () async {
      final base = await state();
      final plain = await makeRealProfileTask(base);
      final empty = await makeRealProfileTask(
        base.copyWith(splitTunnelRules: const [], splitTunnelReplace: true),
      );
      expect(empty.yaml, plain.yaml);
    });

    test('replacing rules leaves only the split tunnel', () async {
      final split = splitTunnelRules(_two, Mode.global);
      final result = await makeRealProfileTask(
        (await state(sites: true)).copyWith(
          realPatchConfig: const PatchClashConfig(mode: Mode.rule),
          splitTunnelRules: split.rules,
          splitTunnelReplace: split.replace,
        ),
      );
      final config = loadYaml(result.yaml) as YamlMap;
      expect(config['mode'], 'rule');
      expect(config['rules'], split.rules);
    });

    test('rule routing puts the split tunnel first', () async {
      final split = splitTunnelRules(
        _two.copyWith(mode: SplitTunnelMode.exceptSelected),
        Mode.rule,
      );
      final result = await makeRealProfileTask(
        (await state()).copyWith(
          splitTunnelRules: split.rules,
          splitTunnelReplace: split.replace,
        ),
      );
      expect((loadYaml(result.yaml) as YamlMap)['rules'], [
        'PROCESS-NAME,chrome.exe,DIRECT',
        'PROCESS-NAME,Telegram.exe,DIRECT',
        ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Servers',
      ]);
    });

    test('global routing carries the torrent rules ahead of GLOBAL', () async {
      final split = splitTunnelRules(const SplitTunnelProps(), Mode.global);
      final result = await makeRealProfileTask(
        (await state()).copyWith(
          realPatchConfig: const PatchClashConfig(mode: Mode.rule),
          splitTunnelRules: split.rules,
          splitTunnelReplace: split.replace,
        ),
      );
      final rules = (loadYaml(result.yaml) as YamlMap)['rules'] as YamlList;
      expect(
        rules.first,
        torrentDirectRulesFor(SupportPlatform.currentPlatform).first,
      );
      expect(
        rules,
        contains(torrentDirectRulesFor(SupportPlatform.currentPlatform).last),
      );
      expect(rules.last, 'MATCH,GLOBAL');
      expect(rules, isNot(contains('DOMAIN,existing.example,DIRECT')));
      // This profile has no local sites rule set, so nothing names it.
      expect(rules, isNot(contains(directSitesRule)));
    });

    test('a subscription with the local sites keeps their rule', () async {
      final global = splitTunnelRules(const SplitTunnelProps(), Mode.global);
      final globalConfig = loadYaml(
        (await makeRealProfileTask(
          (await state(sites: true)).copyWith(
            realPatchConfig: const PatchClashConfig(mode: Mode.rule),
            splitTunnelRules: global.rules,
            splitTunnelReplace: global.replace,
          ),
        )).yaml,
      ) as YamlMap;
      expect(globalConfig['rules'], [
        ...torrentDirectRulesFor(SupportPlatform.currentPlatform),
        directSitesRule,
        'MATCH,GLOBAL',
      ]);
      expect(
        (globalConfig['rule-providers'] as YamlMap)['direct-sites']['payload'],
        ['+.vk.com'],
      );

      final rule = splitTunnelRules(
        const SplitTunnelProps(torrentDirect: false),
        Mode.rule,
      );
      final ruleConfig = loadYaml(
        (await makeRealProfileTask(
          (await state(sites: true)).copyWith(
            splitTunnelRules: rule.rules,
            splitTunnelReplace: rule.replace,
          ),
        )).yaml,
      ) as YamlMap;
      expect(ruleConfig['rules'], [
        directSitesRule,
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Servers',
      ]);
    });

    test('without the rule set the local sites rule is dropped', () async {
      final split = splitTunnelRules(
        const SplitTunnelProps(torrentDirect: false),
        Mode.global,
      );
      final result = await makeRealProfileTask(
        (await state()).copyWith(
          realPatchConfig: const PatchClashConfig(mode: Mode.rule),
          splitTunnelRules: split.rules,
          splitTunnelReplace: split.replace,
        ),
      );
      expect((loadYaml(result.yaml) as YamlMap)['rules'], ['MATCH,GLOBAL']);
    });
  });
}

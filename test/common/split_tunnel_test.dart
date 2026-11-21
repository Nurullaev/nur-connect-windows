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
        (const SplitTunnelProps(apps: ['chrome.exe']), Mode.global),
        (const SplitTunnelProps(enabled: true), Mode.global),
        (_two, Mode.direct),
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
        'MATCH,GLOBAL',
      ]);
      expect(split.replace, isTrue);
      expect(splitTunnelCoreMode(_two, Mode.global), Mode.rule);
    });

    test('a single selected app needs no OR', () {
      const props = SplitTunnelProps(enabled: true, apps: ['chrome.exe']);
      expect(splitTunnelRules(props, Mode.rule).rules, [
        'NOT,((PROCESS-NAME,chrome.exe)),DIRECT',
      ]);
    });

    test('excepted apps go direct and rule routing keeps its rules', () {
      final props = _two.copyWith(mode: SplitTunnelMode.exceptSelected);
      final split = splitTunnelRules(props, Mode.rule);
      expect(split.rules, [
        'PROCESS-NAME,chrome.exe,DIRECT',
        'PROCESS-NAME,Telegram.exe,DIRECT',
      ]);
      expect(split.replace, isFalse);
      expect(splitTunnelCoreMode(props, Mode.rule), Mode.rule);
    });

    test('the key follows the routing mode', () {
      expect(
        splitTunnelKey(_two, Mode.global),
        isNot(splitTunnelKey(_two, Mode.rule)),
      );
    });
  });

  test('props read back from JSON, an unknown mode falling back', () {
    final json =
        jsonDecode(jsonEncode(const NetworkProps(splitTunnel: _two)))
            as Map<String, Object?>;
    expect(NetworkProps.fromJson(json).splitTunnel, _two);
    expect(
      SplitTunnelProps.fromJson({
        'enabled': true,
        'mode': 'later',
        'apps': [],
      }).mode,
      SplitTunnelMode.onlySelected,
    );
    expect(NetworkProps.fromJson({}).splitTunnel, const SplitTunnelProps());
  });

  group('makeRealProfileTask', () {
    Future<MakeRealProfileState> state() async => MakeRealProfileState(
      profilesPath: '/profiles',
      profileId: 7,
      rawConfig: await decodeJSONTask<Map<String, dynamic>>(
        jsonEncode({
          'proxies': [],
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
        (await state()).copyWith(
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
        'DOMAIN,existing.example,DIRECT',
        'MATCH,Servers',
      ]);
    });
  });
}

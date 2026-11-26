import 'dart:io';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh desktop installs check app releases by default', () {
    expect(
      Config.realFromJson(null).appSettingProps.autoCheckUpdate,
      Platform.isWindows || Platform.isMacOS,
    );
    expect(
      AppSettingProps.safeFromJson({}).autoCheckUpdate,
      Platform.isWindows || Platform.isMacOS,
    );
    expect(
      Config.realFromJson({}).appSettingProps.autoCheckUpdate,
      Platform.isWindows || Platform.isMacOS,
    );
  });

  test('a fresh configuration uses VPN routing without system proxy', () {
    final config = Config.realFromJson(null);
    expect(config.patchClashConfig.tun.enable, isTrue);
    expect(config.networkProps.systemProxy, isFalse);
  });

  test('an explicit user choice stays off after loading and saving', () {
    final config = Config.realFromJson({
      'appSettingProps': {'autoCheckUpdate': false},
    });
    expect(config.appSettingProps.autoCheckUpdate, isFalse);
    expect(
      Config.realFromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, Object?>,
      ).appSettingProps.autoCheckUpdate,
      isFalse,
    );
  });
}

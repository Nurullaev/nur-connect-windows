import 'dart:io';
import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh Windows installs check app releases by default', () {
    expect(
      Config.realFromJson(null).appSettingProps.autoCheckUpdate,
      Platform.isWindows,
    );
    expect(
      AppSettingProps.safeFromJson({}).autoCheckUpdate,
      Platform.isWindows,
    );
    expect(
      Config.realFromJson({}).appSettingProps.autoCheckUpdate,
      Platform.isWindows,
    );
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

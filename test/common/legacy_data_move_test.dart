import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('nur-data-move-'));
  tearDown(() => root.deleteSync(recursive: true));

  Directory folder(String company, [String product = 'NurConnectWindows']) =>
      Directory(p.join(root.path, company, product));

  test('the old folder moves into an empty new one', () async {
    final legacy = folder(legacyWindowsCompanyName)
      ..createSync(recursive: true);
    File(
      p.join(legacy.path, 'shared_preferences.json'),
    ).writeAsStringSync('{}');
    final current = folder(windowsCompanyName)..createSync(recursive: true);

    await moveLegacyWindowsData(current);

    expect(legacy.existsSync(), isFalse);
    expect(
      File(p.join(current.path, 'shared_preferences.json')).existsSync(),
      isTrue,
    );
  });

  test('a new folder with data of its own is left alone', () async {
    final legacy = folder(legacyWindowsCompanyName)
      ..createSync(recursive: true);
    File(p.join(legacy.path, 'old.json')).writeAsStringSync('{}');
    final current = folder(windowsCompanyName)..createSync(recursive: true);
    File(p.join(current.path, 'new.json')).writeAsStringSync('{}');

    await moveLegacyWindowsData(current);

    expect(File(p.join(legacy.path, 'old.json')).existsSync(), isTrue);
    expect(File(p.join(current.path, 'old.json')).existsSync(), isFalse);
  });

  test('nothing to move and other folders change nothing', () async {
    final current = folder(windowsCompanyName)..createSync(recursive: true);
    await moveLegacyWindowsData(current);
    expect(current.existsSync(), isTrue);

    final other = folder('Someone')..createSync(recursive: true);
    folder(legacyWindowsCompanyName).createSync(recursive: true);
    await moveLegacyWindowsData(other);
    expect(folder(legacyWindowsCompanyName).existsSync(), isTrue);
  });

  test('the pre copy moves its own folder', () async {
    final legacy = folder(legacyWindowsCompanyName, 'NurConnectWindows.pre')
      ..createSync(recursive: true);
    File(p.join(legacy.path, 'a')).writeAsStringSync('1');
    final current = folder(windowsCompanyName, 'NurConnectWindows.pre');

    await moveLegacyWindowsData(current);

    expect(File(p.join(current.path, 'a')).existsSync(), isTrue);
    expect(legacy.existsSync(), isFalse);
  });
}

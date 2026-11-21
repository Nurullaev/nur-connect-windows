import 'dart:io';

import 'package:test/test.dart';

final _passwordInputType = RegExp(
  r'\benableSuggestions:\s*false\b|\bTextInputType\.visiblePassword\b',
);

const _secretFields = {'lib/ui/input.dart', 'lib/features/form/form_row.dart'};

/// Windows lists paths with backslashes; the rules here are written with `/`.
String _posix(String path) => path.replaceAll(r'\', '/');

void main() {
  test('only secret fields ask Android for a password keyboard', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File ||
          !_posix(entity.path).endsWith('.dart') ||
          _posix(entity.path).contains('/generated/') ||
          _secretFields.contains(_posix(entity.path))) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _passwordInputType.firstMatch(lines[i]);
        if (match != null) {
          offenders.add(
            '${_posix(entity.path)}:${i + 1} — ${match[0]} makes Android input '
            'methods treat the field as a password, with no clipboard or '
            'Chinese input; keep autocorrect: false alone.',
          );
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

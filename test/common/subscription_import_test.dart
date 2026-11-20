import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes direct, OS, clipboard and QR imports consistently', () {
    const url = 'https://example.test/sub/private?key=one%2Btwo';
    final wrapped = Uri(
      scheme: 'nurconnect-win',
      host: 'install-config',
      queryParameters: {'url': url},
    ).toString();
    expect(subscriptionLinkFromInput('  $url  '), url);
    expect(subscriptionLinkFromInput(wrapped), url);
    expect(profileUrlFromQrCodes(['not a link', wrapped]), url);
    expect(
      subscriptionLinkFromInput('trojan://pass@example.test:443#One'),
      startsWith('trojan://'),
    );
  });

  test('rejects ambiguous, nested, foreign and non-HTTP import targets', () {
    for (final input in [
      '',
      'https://',
      'https://example.test:0/sub',
      'https://example.test:70000/sub',
      'ftp://example.test/sub',
      'https://example.test/a\nhttps://example.test/b',
      'other://install-config?url=https%3A%2F%2Fexample.test',
      'nurconnect-win://install-config?url=file%3A%2F%2F%2Fsecret',
      'nurconnect-win://install-config?url=https%3A%2F%2Fa.test&url=https%3A%2F%2Fb.test',
    ]) {
      expect(
        () => subscriptionLinkFromInput(input),
        throwsA(isA<SubscriptionImportException>()),
      );
    }
  });

  test('rejects empty, HTML and Xray JSON without leaking response text', () {
    for (final body in [
      '',
      '\uFEFF \n',
      '<!DOCTYPE html><p>private-token</p>',
      '{"outbounds":[]}',
      '[{"outbounds":[]}]',
    ]) {
      expect(
        () => checkSubscriptionResponse(Uint8List.fromList(utf8.encode(body))),
        throwsA(
          isA<SubscriptionImportException>().having(
            (e) => e.toString().contains('private-token'),
            'no body in error',
            false,
          ),
        ),
      );
    }
  });

  test('leaves YAML, age ciphertext and Mihomo JSON for Core validation', () {
    for (final body in [
      'proxies: []',
      'age-encryption.org/v1\n-> X25519 data',
      '{"proxies":[]}',
      '{"proxy-providers":{}}',
    ]) {
      expect(
        () => checkSubscriptionResponse(Uint8List.fromList(utf8.encode(body))),
        returnsNormally,
      );
    }
  });

  test(
    'import errors hide unknown transport details and do not infer expiry',
    () async {
      final l10n = await AppLocalizations.load(const Locale('en'));
      final error = DioException(
        requestOptions: RequestOptions(
          path: 'https://example.test/private-token',
        ),
        message: 'private-token',
      );
      expect(
        subscriptionImportErrorMessage(error, l10n),
        isNot(contains('private-token')),
      );
      final denied = DioException.badResponse(
        statusCode: 403,
        requestOptions: error.requestOptions,
        response: Response(
          requestOptions: error.requestOptions,
          statusCode: 403,
        ),
      );
      expect(
        subscriptionImportErrorMessage(denied, l10n),
        l10n.networkBadResponseError(403),
      );
      expect(
        subscriptionImportErrorMessage(denied, l10n),
        isNot(contains('expired')),
      );
    },
  );
}

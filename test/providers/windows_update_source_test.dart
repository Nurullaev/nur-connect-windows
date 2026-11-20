import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Releases implements HttpClientAdapter {
  final urls = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri);
    final Object data = options.uri.path.endsWith('/latest')
        ? {
            'tag_name': 'v0.0.1',
            'prerelease': false,
            'draft': false,
            'assets': [],
          }
        : [];
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows release checks ignore a subscription update URL', () async {
    final adapter = _Releases();
    final previous = request.dio.httpClientAdapter;
    request.dio.httpClientAdapter = adapter;
    addTearDown(() => request.dio.httpClientAdapter = previous);
    globalState.packageInfo = PackageInfo(
      appName: 'Nur Connect',
      packageName: windowsAppId,
      version: '0.1.0-pre.1',
      buildNumber: '2',
    );
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(
              id: 1,
              autoUpdateDuration: Duration.zero,
              providerHeaders: {
                'flclashx-update': 'https://other.example/manifest.json',
                'flclashx-update-pre': 'https://other.example/manifest.json',
              },
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 1;
    expect(
      await container.read(commonActionProvider.notifier).checkForUpdate(),
      isNull,
    );
    expect(adapter.urls, isNotEmpty);
    for (final url in adapter.urls) {
      expect(url.host, 'api.github.com');
      expect(url.path, startsWith('/repos/$productRepository/releases'));
    }
  }, skip: !Platform.isWindows);
}

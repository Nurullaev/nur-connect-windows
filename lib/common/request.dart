import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;

class Request {
  late final Dio dio;
  late final Dio _clashDio;

  ProviderReader? _read;

  void attach(ProviderReader read) {
    _read = read;
  }

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = _proxiedAdapter();
  }

  IOHttpClientAdapter _proxiedAdapter() => IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (Uri uri) {
        client.userAgent = globalState.ua;
        final read = _read;
        if (read == null) {
          return 'DIRECT';
        }
        return FlClashHttpOverrides.findProxyForReader(read, uri);
      };
      return client;
    },
  );

  /// The adapter keeps the first HttpClient it makes, under whatever
  /// HttpOverrides held then; a test that changes them starts a new one.
  @visibleForTesting
  void resetClient() => _clashDio.httpClientAdapter = _proxiedAdapter();

  Future<Response<T>> _download<T>(
    String url,
    ResponseType responseType, {
    Duration timeout = downloadTimeoutDuration,
    Map<String, String> headers = const {},
  }) {
    final target = downloadTarget(url);
    final cancelToken = CancelToken();
    var oversized = false;
    return _clashDio
        .getUri<T>(
          target.uri,
          options: Options(
            responseType: responseType,
            headers: {...headers, ...target.headers},
            // Nothing asks for a range, so a 206 is a cut-off copy.
            validateStatus: (status) =>
                status != null &&
                status >= 200 &&
                status < 300 &&
                status != HttpStatus.partialContent,
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (received > maxDownloadBytes || total > maxDownloadBytes) {
              oversized = true;
              cancelToken.cancel();
            }
          },
        )
        .catchError(
          (Object _) =>
              throw MessageException(currentAppLocalizations.downloadTooLarge),
          test: (_) => oversized,
        )
        .timeout(
          timeout,
          onTimeout: () {
            cancelToken.cancel();
            throw DioException.receiveTimeout(
              timeout: timeout,
              requestOptions: RequestOptions(path: url),
            );
          },
        );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(
    String url, {
    Duration timeout = downloadTimeoutDuration,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _download<Uint8List>(
        url,
        ResponseType.bytes,
        timeout: timeout,
        headers: headers,
      );
    } catch (e) {
      commonPrint.log(
        'getFileResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    try {
      return await _download<String>(url, ResponseType.plain);
    } catch (e) {
      commonPrint.log(
        'getTextResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  /// Null when this build is current; throws when GitHub cannot be asked.
  ///
  /// [installs] names the files this copy can update itself from. Windows
  /// and macOS share the releases, so one may come out for the other alone:
  /// a release without any of them is passed over for the newest one that
  /// has one, and never offers a download that is not there.
  Future<Map<String, dynamic>?> checkForUpdate({
    Set<String> installs = const {},
  }) async {
    final release = globalState.isPre
        ? await latestPrerelease(installs: installs)
        : await latestRelease(installs: installs);
    if (release == null) {
      return null;
    }
    final remoteVersion = release['tag_name'] as String;
    final version = globalState.packageInfo.displayVersion;
    final hasUpdate =
        compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
    return hasUpdate ? release : null;
  }

  /// A pre-release installs as its own app, which a stable release would not
  /// upgrade, so it only hears of newer pre-releases.
  @visibleForTesting
  Future<Map<String, dynamic>?> latestPrerelease({
    Set<String> installs = const {},
  }) async {
    try {
      return newestPrerelease(await _releases(), installs: installs);
    } on DioException catch (error) {
      commonPrint.log(
        'releases API failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    final feed = await dio.get<String>(
      'https://github.com/$repository/releases.atom',
      options: Options(responseType: ResponseType.plain),
    );
    return _withDownload(
      newestPrereleaseInFeed(feed.data ?? ''),
      installs: installs,
    );
  }

  Future<List<dynamic>> _releases() async {
    final releases = <dynamic>[];
    String? next =
        'https://api.github.com/repos/$repository/releases?per_page=100';
    for (var page = 0; next != null && page < _releasePages; page++) {
      final response = await dio.get<List<dynamic>>(
        next,
        options: Options(responseType: ResponseType.json),
      );
      releases.addAll(response.data ?? const []);
      next = nextPageOf(response.headers.value('link'));
    }
    return releases;
  }

  /// The release page redirect still answers once the hourly API quota is spent.
  /// Null when no stable release carries any of [installs].
  @visibleForTesting
  Future<Map<String, dynamic>?> latestRelease({
    Set<String> installs = const {},
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      final latest = response.data!;
      if (carriesInstall(latest, installs) != false) {
        return latest;
      }
      return newestStableRelease(await _releases(), installs: installs);
    } on DioException catch (error) {
      commonPrint.log(
        'latest release API failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    final response = await dio.get<void>(
      'https://github.com/$repository/releases/latest',
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final location = response.headers.value(HttpHeaders.locationHeader);
    final segments = Uri.tryParse(location ?? '')?.pathSegments ?? const [];
    final tagIndex = segments.indexOf('tag') + 1;
    if (tagIndex == 0 || tagIndex >= segments.length) {
      throw FormatException('No release tag in the redirect', location);
    }
    return _withDownload({'tag_name': segments[tagIndex]}, installs: installs);
  }

  /// A release known by its tag alone, as the quota-free fallbacks give it,
  /// is kept unless every one of [installs] is missing from it. Only a 404
  /// says a file is missing; any other answer leaves the download to tell.
  Future<Map<String, dynamic>?> _withDownload(
    Map<String, dynamic>? release, {
    required Set<String> installs,
  }) async {
    final tag = release?['tag_name'];
    if (release == null || installs.isEmpty || tag is! String) {
      return release;
    }
    for (final name in installs) {
      try {
        final response = await dio.head<void>(
          'https://github.com/$repository/releases/download/$tag/$name',
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null,
          ),
        );
        if (response.statusCode != HttpStatus.notFound) {
          return release;
        }
      } on DioException {
        return release;
      }
    }
    return null;
  }
}

final request = Request();

const _releasePages = 5;

/// The app's own pre-release tags; Core builds and other releases share the
/// list under tags compareVersions cannot read.
final _prereleaseTag = RegExp(r'^v\d+\.\d+\.\d+-pre\.\d+$');

Map<String, dynamic>? newestPrerelease(
  List<dynamic> releases, {
  Set<String> installs = const {},
}) => _newestRelease(
  releases,
  prerelease: true,
  tagPattern: _prereleaseTag,
  installs: installs,
);

final _stableTag = RegExp(r'^v\d+\.\d+\.\d+$');

Map<String, dynamic>? newestStableRelease(
  List<dynamic> releases, {
  Set<String> installs = const {},
}) => _newestRelease(
  releases,
  prerelease: false,
  tagPattern: _stableTag,
  installs: installs,
);

Map<String, dynamic>? _newestRelease(
  List<dynamic> releases, {
  required bool prerelease,
  required RegExp tagPattern,
  required Set<String> installs,
}) {
  Map<String, dynamic>? newest;
  for (final release in releases) {
    if (release is! Map<String, dynamic> ||
        (release['prerelease'] == true) != prerelease ||
        release['draft'] == true ||
        carriesInstall(release, installs) == false) {
      continue;
    }
    final tag = release['tag_name'];
    if (tag is! String || !tagPattern.hasMatch(tag)) {
      continue;
    }
    if (newest == null || _newer(tag, newest['tag_name'] as String)) {
      newest = release;
    }
  }
  return newest;
}

/// Whether [release] lists one of [installs]: null when it lists no files
/// at all, and true when there is nothing to look for.
bool? carriesInstall(Map<String, dynamic> release, Set<String> installs) {
  if (installs.isEmpty) {
    return true;
  }
  final assets = release['assets'];
  if (assets is! List) {
    return null;
  }
  return assets.any(
    (asset) => asset is Map && installs.contains(asset['name']),
  );
}

/// The releases feed, which is not rate limited, names tags but not which
/// are pre-releases; the app's pre-release tags say so themselves.
Map<String, dynamic>? newestPrereleaseInFeed(String feed) {
  String? newest;
  for (final match in RegExp(r'/releases/tag/([^"<\s]+)').allMatches(feed)) {
    final tag = Uri.decodeComponent(match.group(1)!);
    if (_prereleaseTag.hasMatch(tag) &&
        (newest == null || _newer(tag, newest))) {
      newest = tag;
    }
  }
  return newest == null ? null : {'tag_name': newest};
}

String? nextPageOf(String? link) {
  if (link == null) {
    return null;
  }
  for (final part in link.split(',')) {
    final match = RegExp(r'<([^>]+)>;\s*rel="next"').firstMatch(part);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

bool _newer(String tag, String than) =>
    compareVersions(_versionOfTag(tag), _versionOfTag(than)) > 0;

String _versionOfTag(String tag) => tag.replaceFirst(RegExp('^v'), '');

/// How a host let a download down: [soft] when it may be back in a moment,
/// [hard] when the host itself is gone or no longer serves the resource.
enum HostFailure { soft, hard }

const _goneStatuses = {HttpStatus.notFound, HttpStatus.gone};

/// Errno of a name that does not resolve or a port nobody listens on, on
/// macOS and Linux (glibc), then Windows.
const _hardSocketErrors = {8, -2, -3, -5, 61, 111, 11001, 11004, 10061};

HostFailure hostFailureOf(Object error) {
  final cause = error is DioException ? error.error ?? error : error;
  final hard = switch (cause) {
    MessageException() => true,
    SubscriptionImportException(
      issue: SubscriptionImportIssue.invalidConfig ||
          SubscriptionImportIssue.wrongFormat,
    ) =>
      true,
    HandshakeException() || CertificateException() => true,
    SocketException(:final osError, :final message) =>
      _hardSocketErrors.contains(osError?.errorCode) ||
          message.contains('Failed host lookup') ||
          message.contains('Connection refused'),
    DioException(type: DioExceptionType.badCertificate) => true,
    DioException(type: DioExceptionType.badResponse, :final response) =>
      _goneStatuses.contains(response?.statusCode),
    _ => false,
  };
  return hard ? HostFailure.hard : HostFailure.soft;
}

/// Some subscription servers send a gzip or zlib body without saying so in
/// Content-Encoding, which is the only signal dart:io decompresses on.
Future<Uint8List> decompressDownload(Uint8List bytes) async {
  if (_unlabeledCodecOf(bytes) == null) {
    return bytes;
  }
  final inflated = await compute(decompressUnlabeled, bytes);
  if (inflated == null) {
    throw MessageException(currentAppLocalizations.downloadTooLarge);
  }
  return inflated;
}

@visibleForTesting
Uint8List? decompressUnlabeled(
  Uint8List bytes, {
  int limit = maxDownloadBytes,
}) {
  final codec = _unlabeledCodecOf(bytes);
  if (codec == null) {
    return bytes;
  }
  final output = _CappedSink(limit);
  try {
    codec.decoder.startChunkedConversion(output)
      ..add(bytes)
      ..close();
  } on _OutputTooLarge {
    return null;
  } on FormatException {
    return bytes;
  }
  return output.bytes.takeBytes();
}

Codec<List<int>, List<int>>? _unlabeledCodecOf(Uint8List bytes) =>
    switch (bytes) {
      [0x1f, 0x8b, ...] => gzip,
      [0x78, final flags, ...] when (0x78 << 8 | flags) % 31 == 0 => zlib,
      _ => null,
    };

final class _OutputTooLarge implements Exception {
  const _OutputTooLarge();
}

final class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.limit);

  final int limit;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > limit) {
      throw const _OutputTooLarge();
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

/// dart:io turns [Uri.userInfo] into Basic credentials still percent-encoded.
@visibleForTesting
({Uri uri, Map<String, Object> headers}) downloadTarget(String url) {
  final uri = url.webUri ?? Uri.parse(url);
  if (uri.userInfo.isEmpty) {
    return (uri: uri, headers: const {});
  }
  final credentials = uri.userInfo.split(':').map(_decodeUserInfo).join(':');
  return (
    uri: uri.replace(userInfo: ''),
    headers: {
      HttpHeaders.authorizationHeader:
          'Basic ${base64.encode(utf8.encode(credentials))}',
    },
  );
}

String _decodeUserInfo(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

String? getFileNameForDisposition(String? disposition) {
  if (disposition == null) return null;
  final parseValue = HeaderValue.parse(disposition);
  final parameters = parseValue.parameters;
  final fileNamePointKey = parameters.keys.firstWhere(
    (key) => key == 'filename*',
    orElse: () => '',
  );
  if (fileNamePointKey.isNotEmpty) {
    final res = parameters[fileNamePointKey]?.split("''") ?? [];
    if (res.length >= 2) {
      return Uri.decodeComponent(res[1]);
    }
  }
  final fileNameKey = parameters.keys.firstWhere(
    (key) => key == 'filename',
    orElse: () => '',
  );
  if (fileNameKey.isEmpty) return null;
  return parameters[fileNameKey];
}

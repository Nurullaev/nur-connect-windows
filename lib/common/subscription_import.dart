import 'dart:convert';
import 'dart:typed_data';

import 'protocol.dart';
import 'string.dart';

enum SubscriptionImportIssue {
  invalidLink,
  emptyResponse,
  wrongFormat,
  invalidConfig,
  deviceLimit,
  deviceUnsupported,
}

/// Never retains a subscription URL, response body or Core diagnostic.
final class SubscriptionImportException implements Exception {
  const SubscriptionImportException(this.issue);

  final SubscriptionImportIssue issue;

  bool get isRefusal =>
      issue == SubscriptionImportIssue.deviceLimit ||
      issue == SubscriptionImportIssue.deviceUnsupported;

  @override
  String toString() => 'SubscriptionImportException(${issue.name})';
}

/// The same parser is used by text, clipboard, QR and OS import links.
String subscriptionLinkFromInput(String input) {
  final text = input.trim();
  if (text.isEmpty || RegExp(r'\s').hasMatch(text)) {
    throw const SubscriptionImportException(
      SubscriptionImportIssue.invalidLink,
    );
  }
  if (text.isShareLink) return text;
  final uri = Uri.tryParse(text);
  if (uri != null && protocolSchemes.contains(uri.scheme)) {
    final List<String>? urls;
    try {
      urls = uri.queryParametersAll['url'];
    } on FormatException {
      throw const SubscriptionImportException(
        SubscriptionImportIssue.invalidLink,
      );
    }
    if (uri.host != 'install-config' || urls == null || urls.length != 1) {
      throw const SubscriptionImportException(
        SubscriptionImportIssue.invalidLink,
      );
    }
    return _subscriptionUrl(urls.single.trim());
  }
  return _subscriptionUrl(text);
}

String _subscriptionUrl(String text) {
  final uri = Uri.tryParse(text);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      RegExp(r'\s').hasMatch(text)) {
    throw const SubscriptionImportException(
      SubscriptionImportIssue.invalidLink,
    );
  }
  try {
    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
      throw const SubscriptionImportException(
        SubscriptionImportIssue.invalidLink,
      );
    }
  } on FormatException {
    throw const SubscriptionImportException(
      SubscriptionImportIssue.invalidLink,
    );
  }
  return text;
}

/// An early format check, followed by the Core's full validation. Encrypted
/// age content and YAML stay untouched; valid Mihomo JSON is also accepted.
void checkSubscriptionResponse(Uint8List bytes) {
  final text = utf8
      .decode(bytes, allowMalformed: true)
      .replaceFirst('\uFEFF', '')
      .trim();
  if (text.isEmpty) {
    throw const SubscriptionImportException(
      SubscriptionImportIssue.emptyResponse,
    );
  }
  if (text.startsWith('<')) {
    throw const SubscriptionImportException(
      SubscriptionImportIssue.wrongFormat,
    );
  }
  if (text.startsWith('{') || text.startsWith('[')) {
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const SubscriptionImportException(
        SubscriptionImportIssue.wrongFormat,
      );
    }
    if (json is! Map ||
        (!json.containsKey('proxies') &&
            !json.containsKey('proxy-providers') &&
            !json.containsKey('proxy-groups') &&
            !json.containsKey('rules'))) {
      throw const SubscriptionImportException(
        SubscriptionImportIssue.wrongFormat,
      );
    }
  }
}

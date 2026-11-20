import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'print.dart';
import 'protocol.dart';
import 'string.dart';
import 'subscription_import.dart';

String? profileUrlFromQrCodes(Iterable<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      continue;
    }
    try {
      return subscriptionLinkFromInput(text);
    } on SubscriptionImportException {
      continue;
    }
  }
  return null;
}

String? _installConfigUrl(Uri uri) {
  if (!protocolSchemes.contains(uri.scheme) || uri.host != 'install-config') {
    return null;
  }
  try {
    return subscriptionLinkFromInput(uri.toString());
  } on SubscriptionImportException {
    return null;
  }
}

class LinkManager {
  static LinkManager? _instance;
  StreamSubscription? subscription;
  Uri? _pendingUri;

  LinkManager._internal();

  @visibleForTesting
  Stream<Uri> Function() uriLinkStream = () => AppLinks().uriLinkStream;

  /// Linux argv: the gtk plugin hooks GApplication too late to see it.
  void seedInitialLink(List<String> args) {
    for (final arg in args) {
      final uri = Uri.tryParse(arg);
      if (uri != null && protocolSchemes.contains(uri.scheme)) {
        _pendingUri = uri;
        return;
      }
    }
  }

  Future<void> initAppLinksListen(
    Function(String url) installConfigCallBack,
  ) async {
    destroy();
    subscription = uriLinkStream().listen((uri) {
      _handle(uri, installConfigCallBack);
    });
    final pending = _pendingUri;
    _pendingUri = null;
    if (pending != null) {
      _handle(pending, installConfigCallBack);
    }
  }

  /// The nested url carries the subscription's credentials, so the log
  /// names only its host.
  void _handle(Uri uri, Function(String url) installConfigCallBack) {
    final url = _installConfigUrl(uri);
    final target = url?.webUri?.host;
    commonPrint.log(
      'onAppLink: ${uri.scheme}://${uri.host}'
      '${target == null ? '' : ' for $target'}',
    );
    if (url != null) {
      installConfigCallBack(url);
    }
  }

  void destroy() {
    if (subscription != null) {
      subscription?.cancel();
      subscription = null;
    }
  }

  factory LinkManager() {
    _instance ??= LinkManager._internal();
    return _instance!;
  }
}

final linkManager = LinkManager();

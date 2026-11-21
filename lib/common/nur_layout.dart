import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart';

/// Whether Windows shows Nur Connect's own home, server page and settings in
/// place of the inherited FlClashX pages.
bool nurWindowsLayout([SupportPlatform? platform]) =>
    !debugUpstreamLayout &&
    (platform ?? SupportPlatform.currentPlatform) == SupportPlatform.Windows;

/// Lets the inherited FlClashX layout tests check those pages on a Windows
/// host, where [nurWindowsLayout] would otherwise replace them.
@visibleForTesting
bool debugUpstreamLayout = false;

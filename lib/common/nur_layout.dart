import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart';

/// Whether Nur Connect desktop shows Nur Connect's own home, server page and settings in
/// place of the inherited FlClashX pages.
bool nurDesktopLayout([SupportPlatform? platform]) =>
    !debugUpstreamLayout &&
    const {
      SupportPlatform.Windows,
      SupportPlatform.MacOS,
    }.contains(platform ?? SupportPlatform.currentPlatform);

/// Lets the inherited FlClashX layout tests check those pages on a Windows
/// host, where [nurDesktopLayout] would otherwise replace them.
@visibleForTesting
bool debugUpstreamLayout = false;

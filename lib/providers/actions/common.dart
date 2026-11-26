part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;
  bool _checkingAutomaticUpdate = false;
  bool _updateDialogOpen = false;

  @override
  void build() {}

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    unawaited(
      globalState.safeRun(
        () => ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            ),
      ),
    );
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMonochromeTrayIcon() {
    ref
        .read(appSettingProvider.notifier)
        .update(
          (state) =>
              state.copyWith(monochromeTrayIcon: !state.monochromeTrayIcon),
        );
  }

  /// The cycling hotkey, which has nowhere to ask before taking the mode
  /// over from the subscription.
  void updateMode() {
    ref
        .read(managedSettingsActionProvider.notifier)
        .takeOverIfLocked('clash.mode');
    final modes = ref.read(availableModesProvider);
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = modes.indexWhere((item) => item == state.mode);
      final nextIndex = index + 1 > modes.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: modes[nextIndex]);
    });
    ref.read(profileHeadersActionProvider.notifier).forgetTakenMode();
  }

  Future<void> updateTraffic() async {
    if (_isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final [traffic, totalTraffic] = await Future.wait([
        _readTraffic(() => _core.getTraffic(onlyStatisticsProxy)),
        _readTraffic(() => _core.getTotalTraffic(onlyStatisticsProxy)),
      ]);
      if (traffic != null) {
        ref.read(trafficsProvider.notifier).addTraffic(traffic);
      }
      if (totalTraffic != null) {
        ref.read(totalTrafficProvider.notifier).value = totalTraffic;
      }
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<Traffic?> _readTraffic(Future<Traffic> Function() request) async {
    try {
      return await request();
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  /// The provider's update manifest for this channel, when its header names
  /// one; it then stands in for GitHub as the update source.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    // Nur Connect Windows releases belong to our repository. A subscription's
    // FlClashX update header must not replace the app's own update source.
    if (system.isWindows || system.isMacOS) {
      return request.checkForUpdate(installs: await _installableFiles());
    }
    final headers = ref.read(currentProfileProvider)?.headers;
    final manifestUrl = globalState.isPre
        ? headers?.preUpdateManifestUrl
        : headers?.updateManifestUrl;
    if (manifestUrl == null) {
      return request.checkForUpdate();
    }
    try {
      return await fetchManifestUpdate(
        request.dio,
        Uri.parse(manifestUrl),
        currentVersion: globalState.packageInfo.displayVersion,
        pre: globalState.isPre,
      );
    } catch (error) {
      commonPrint.log(
        'update manifest failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<Directory> _updateCacheRoot() async =>
      Directory(join((await appPath.cacheDir.future).path, 'update'));

  /// Clears the downloads of updates this app already runs, once it starts
  /// after installing one.
  Future<void> removeInstalledUpdates() async => removeStaleUpdates(
    await _updateCacheRoot(),
    currentVersion: globalState.packageInfo.displayVersion,
  );

  Future<bool> autoCheckUpdate({bool throwOnError = false}) async {
    if (_checkingAutomaticUpdate ||
        !ref.read(appSettingProvider).autoCheckUpdate) {
      return false;
    }
    _checkingAutomaticUpdate = true;
    try {
      final Map<String, dynamic>? res;
      try {
        res = await checkForUpdate();
      } catch (error) {
        commonPrint.log(
          'checkForUpdate failed: ${compactError(error)}',
          logLevel: LogLevel.warning,
        );
        if (throwOnError) rethrow;
        return false;
      }
      if (!ref.mounted ||
          res == null ||
          res['_required'] != true &&
              res['tag_name'] == ref.read(appSettingProvider).hiddenUpdate) {
        return false;
      }
      if (system.isWindows && !ref.read(appVisibleProvider)) {
        await windowPort?.show();
      }
      await checkUpdateResultHandle(data: res);
      return true;
    } finally {
      _checkingAutomaticUpdate = false;
    }
  }

  TextSpan _releaseSpan(BuildContext context, String? body) {
    final version = parseReleaseChangelog(body);
    return TextSpan(
      children: version == null
          ? [
              TextSpan(text: '\n', style: AppTextStyle.subheadline.of(context)),
              for (final submit in parseReleaseBody(body))
                TextSpan(
                  text: '- $submit \n',
                  style: AppTextStyle.subheadline.of(context),
                ),
            ]
          : _changelogSpans(context, version),
    );
  }

  List<TextSpan> _changelogSpans(
    BuildContext context,
    ChangelogVersion version,
  ) {
    return [
      for (final group in version.visibleGroups) ...[
        TextSpan(
          text:
              '\n${changelogGroupTitle(currentAppLocalizations, group.type)}\n',
          style: AppTextStyle.subheadline
              .of(context, emphasized: true)
              .copyWith(
                color: group.type == ChangelogType.breaking
                    ? context.colorScheme.error
                    : context.colorScheme.primary,
              ),
        ),
        for (final entry in group.entries)
          TextSpan(
            text: '• ${entry.text}\n',
            style: AppTextStyle.subheadline.of(context),
          ),
      ],
    ];
  }

  /// The release files this copy can install itself from; none for one that
  /// only opens the release page, such as the portable Windows folder.
  Future<Set<String>> _installableFiles() async {
    final target = (await _updatePlatform()).target;
    return {for (final arch in target.archs) ?target.assetName(arch)};
  }

  Future<UpdatePlatform> _updatePlatform() async {
    try {
      return await resolveUpdatePlatform(
        exitApp: () => ref.read(systemActionProvider.notifier).handleExit(),
      );
    } catch (error) {
      commonPrint.log(
        'Update platform unresolved: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return const ManualUpdatePlatform();
    }
  }

  UpdateErrorKind? _updateInstallBlocker() {
    if (ref.read(safeModeProvider)) {
      return UpdateErrorKind.safeMode;
    }
    if (ref.read(setupActionProvider.notifier).isChangingRun) {
      return UpdateErrorKind.busy;
    }
    return null;
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (_updateDialogOpen) return;
    if (data != null) {
      final context = globalState.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      _updateDialogOpen = true;
      try {
        final notes = _releaseSpan(context, data['body'] as String?);
        final platform = await _updatePlatform();
        final required = data['_required'] == true;
        final downloader = UpdateDownloader(root: _updateCacheRoot);
        await dialogs.showCommonDialog<void>(
          // A required update is not put off by a tap beside it.
          dismissible: !required,
          child: UpdateDialog(
            version: data['tag_name'] as String,
            windowsPrompt: system.isWindows,
            notes: notes,
            onOpenReleasePage: () => unawaited(
              launchUrl(releasePageOf(data, repository: repository)),
            ),
            onHide: system.isWindows || isUser || required
                ? null
                : () => ref
                      .read(appSettingProvider.notifier)
                      .update(
                        (state) => state.copyWith(
                          hiddenUpdate: data['tag_name'] as String,
                        ),
                      ),
            createController: () {
              final controller = UpdateController(
                release: data,
                platform: platform,
                downloader: downloader,
                repository: repository,
                pre: globalState.isPre,
                manifest: data['_isManifest'] == true,
                installBlocker: _updateInstallBlocker,
              );
              app?.onPackageInstallStatus = controller.onInstallStatus;
              return controller;
            },
          ),
        );
      } finally {
        _updateDialogOpen = false;
      }
    } else if (isUser) {
      unawaited(
        dialogs.showAlert(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: currentAppLocalizations.checkUpdateError),
        ),
      );
    }
  }
}

import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _upstreamRepository = 'chen08209/FlClash';
const _coreRepository = 'MetaCubeX/mihomo';
const _baseRepository = 'pluralplay/FlClashX';

/// The running core's version when it answers, else the one this build was
/// made with, else nothing.
final coreVersionProvider = FutureProvider.autoDispose<String?>((ref) async {
  String live = '';
  if (ref.watch(coreStatusProvider) == CoreStatus.connected) {
    try {
      live = await ref.read(coreHandlerProvider).getCoreVersion();
    } catch (_) {}
  }
  final version = live.isNotEmpty ? live : coreVersionDefine;
  return version.isEmpty ? null : version;
});

Future<void> checkAppUpdates(BuildContext context, WidgetRef ref) async {
  if (ref.read(loadingProvider(LoadingTag.checkUpdate))) return;
  final commonAction = ref.read(commonActionProvider.notifier);
  final result = await globalState.loadingRun(
    () async => (release: await commonAction.checkForUpdate()),
    title: context.appLocalizations.checkUpdate,
    tag: LoadingTag.checkUpdate,
  );
  if (result == null) return;
  unawaited(
    commonAction.checkUpdateResultHandle(data: result.release, isUser: true),
  );
}

class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) =>
      checkAppUpdates(context, ref);

  Widget _buildLinkItem({
    required Glyph glyph,
    required String title,
    required String url,
    required String label,
  }) {
    return ListItem(
      leading: _LinkBadge(glyph: glyph),
      title: Text(title),
      subtitle: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const GlyphIcon(AppGlyphs.openExternal),
      onTap: () {
        dialogs.openUrl(url);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isLoading = ref.watch(loadingProvider(LoadingTag.checkUpdate));
    return CommonScaffold(
      isLoading: isLoading,
      title: appLocalizations.about,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.contentTopPadding,
          bottom: 32 + context.bottomInset,
        ),
        children: [
          _AboutHero(
            isCheckingUpdate: isLoading,
            onCheckUpdate: () {
              _checkUpdate(context, ref);
            },
            onEnterDeveloperMode: () {
              ref
                  .read(appSettingProvider.notifier)
                  .update((state) => state.copyWith(developerMode: true));
              context.showNotifier(
                appLocalizations.developerModeEnableTip,
                level: MessageLevel.success,
              );
            },
            onEasterEgg: () => _showEasterEgg(context),
            onUnlockFullSettings: ref.watch(simpleModeProvider)
                ? () {
                    ref.read(fullSettingsUnlockedProvider.notifier).value =
                        true;
                    context.showNotifier(
                      appLocalizations.fullSettingsUnlocked,
                      level: MessageLevel.success,
                    );
                  }
                : null,
          ),
          const SizedBox(height: 8),
          generateSection(
            title: appLocalizations.more,
            items: [
              _buildLinkItem(
                glyph: AppGlyphs.globe,
                title: appLocalizations.website,
                url: productWebsite,
                label: 'nurconnect.app',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.code,
                title: appLocalizations.project,
                url: 'https://github.com/$repository',
                label: 'github.com/$repository',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.link,
                title: appLocalizations.originalRepository,
                url: 'https://github.com/$_upstreamRepository',
                label: 'github.com/$_upstreamRepository',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.cpu,
                title: appLocalizations.core,
                url: 'https://github.com/$_coreRepository',
                label: 'github.com/$_coreRepository',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.code,
                title: 'FlClashX',
                url: 'https://github.com/$_baseRepository',
                label: 'github.com/$_baseRepository',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.link,
                title: appLocalizations.forkAuthor,
                url: 'https://github.com/pluralplay',
                label: 'github.com/pluralplay',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEasterEgg(BuildContext context) {
    dialogs
        .showMessage(
          context: context,
          title: 'REMNAFAMILY ONE LOVE',
          message: const TextSpan(text: '❤️  TRY REMNAWAVE  ❤️'),
          confirmText: 'docs.rw',
          cancelable: true,
        )
        .then((open) {
          if (open == true) {
            dialogs.openUrl('https://docs.rw');
          }
        });
  }
}

class _AboutHero extends ConsumerWidget {
  final bool isCheckingUpdate;
  final VoidCallback onCheckUpdate;
  final VoidCallback onEnterDeveloperMode;
  final VoidCallback onEasterEgg;
  final VoidCallback? onUnlockFullSettings;

  const _AboutHero({
    required this.isCheckingUpdate,
    required this.onCheckUpdate,
    required this.onEnterDeveloperMode,
    required this.onEasterEgg,
    this.onUnlockFullSettings,
  });

  static const _logoSize = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    final coreVersion = ref.watch(coreVersionProvider).value;
    final raised = context.raisedSurfaceLevel.colorOf(colorScheme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          _TapCounter(
            onEnterDeveloperMode: onEnterDeveloperMode,
            onEasterEgg: onEasterEgg,
            onLongPress: onUnlockFullSettings,
            child: ClipOval(
              child: Image.asset(
                'assets/images/icon.png',
                width: _logoSize,
                height: _logoSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            appName,
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Pill(
                label: 'v${globalState.packageInfo.displayVersion}',
                color: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              if (coreVersion != null)
                _Pill(
                  label: 'core: $coreVersion',
                  color: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                ),
              _Pill(
                label: 'GPL-3.0',
                color: raised,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              appLocalizations.desc,
              textAlign: TextAlign.center,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          TonalButton(
            size: TonalButtonSize.bar,
            glyph: AppGlyphs.sync,
            label: appLocalizations.checkUpdate,
            onPressed: isCheckingUpdate ? null : onCheckUpdate,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color foregroundColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: AppShape.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .copyWith(color: foregroundColor),
        ),
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  final Glyph glyph;

  const _LinkBadge({required this.glyph});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.md,
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: GlyphIcon(
            glyph,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Five taps on the logo open developer mode; ten in a row find the egg.
class _TapCounter extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;
  final VoidCallback onEasterEgg;

  /// The simple mode's way back to the full settings, for support.
  final VoidCallback? onLongPress;

  const _TapCounter({
    required this.child,
    required this.onEnterDeveloperMode,
    required this.onEasterEgg,
    this.onLongPress,
  });

  @override
  State<_TapCounter> createState() => _TapCounterState();
}

class _TapCounterState extends State<_TapCounter> {
  static const _developerTaps = 5;
  static const _easterEggTaps = 10;

  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    _timer?.cancel();
    if (_counter == _developerTaps) {
      widget.onEnterDeveloperMode();
    }
    if (_counter >= _easterEggTaps) {
      widget.onEasterEgg();
      _resetCounter();
      return;
    }
    _timer = Timer(const Duration(seconds: 1), _resetCounter);
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      ),
    );
  }
}

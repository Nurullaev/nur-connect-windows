import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/nur_connect_servers.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'layout.dart';
import 'style.dart';
import 'widgets/card.dart';
import 'widgets/core_status_button.dart';
import 'widgets/profile_detail.dart';
import 'widgets/widgets.dart';

/// The Windows home uses the existing profile, server and connection actions.
/// Narrow windows and large text fall back to a single scrollable column.
class NurConnectDashboard extends ConsumerWidget {
  const NurConnectDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final hasProfiles = ref.watch(
      profilesProvider.select((value) => value.isNotEmpty),
    );
    final announcement = ref.watch(announcementProvider) != null;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    return CommonScaffold(
      title: appName,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const Flexible(
            child: Text(appName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      backgroundColor: DashboardColors.of(context).page,
      actions: const [CoreStatusButton()],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth / scale >= 900;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (profile != null) ...[
                const _ConnectionCard(),
                const _ServerCard(),
              ] else
                _WelcomeCard(hasProfiles: hasProfiles),
            ],
          );
          final right = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (profile != null) ...[
                const ProfilesCard(),
                const NetworkSpeedCard(),
              ],
            ],
          );
          return DashboardDensityScope(
            // Natural-height cards avoid fixed-height overflow at large text.
            density: DashboardDensity.mobile,
            scale: scale,
            child: SingleChildScrollView(
              key: const PageStorageKey('nur-connect-home'),
              padding: EdgeInsets.fromLTRB(
                24,
                16 + context.contentTopPadding,
                24,
                24 + context.bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [
                      if (announcement) const AnnouncementCard(),
                      Text(
                        l10n.nurHomeSubtitle,
                        style: AppTextStyle.callout.of(context),
                      ),
                      if (twoColumns && profile != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 20,
                          children: [
                            Expanded(flex: 6, child: left),
                            Expanded(flex: 5, child: right),
                          ],
                        )
                      else ...[
                        left,
                        right,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeCard extends ConsumerWidget {
  const _WelcomeCard({required this.hasProfiles});

  final bool hasProfiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    return DashboardCard(
      key: const ValueKey('nur-welcome'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          spacing: 20,
          children: [
            GlyphIcon(
              AppGlyphs.profiles,
              size: 48,
              color: context.colorScheme.primary,
            ),
            Text(
              l10n.nurWelcomeTitle,
              textAlign: TextAlign.center,
              style: AppTextStyle.title2.of(context, emphasized: true),
            ),
            Text(l10n.nurWelcomeHint, textAlign: TextAlign.center),
            FilledButton(
              onPressed: () {
                if (hasProfiles) {
                  showProfilesSheet(context);
                } else {
                  unawaited(addProfileByLink(context, ref));
                }
              },
              child: Text(
                hasProfiles ? l10n.switchProfile : l10n.nurAddSubscription,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends ConsumerStatefulWidget {
  const _ConnectionCard();

  @override
  ConsumerState<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final running = !ref.read(isStartProvider);
    if (running && ref.read(currentProfileProvider) == null) return;
    setState(() => _busy = true);
    try {
      await globalState.safeRun(
        () => ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final running = ref.watch(isStartProvider);
    final suspended = running && ref.watch(suspendProvider);
    final core = ref.watch(coreStatusProvider);
    final safeMode = ref.watch(safeModeProvider);
    final time = ref.watch(runTimeProvider);
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );
    final tun = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final routing =
        tun || (systemProxy && ref.watch(systemProxyAllowedProvider));
    final changing = _busy || core == CoreStatus.connecting;
    final ready = running && !suspended && core == CoreStatus.connected;
    final refusal = ref.watch(currentProfileProvider)?.accessRefusal;
    final status = refusal != null
        ? subscriptionImportErrorMessage(
            SubscriptionImportException(refusal),
            l10n,
          )
        : changing
        ? l10n.connecting
        : suspended
        ? l10n.suspended
        : ready && routing
        ? l10n.connected
        : l10n.disconnected;
    return DashboardCard(
      key: const ValueKey('nur-connection'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: GlyphIcon(
                    AppGlyphs.status,
                    size: 24,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: AppTextStyle.headline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    if (ready)
                      Text(
                        getTimeText(time),
                        style: AppTextStyle.callout.of(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const _ConnectionModeSelector(),
          if (!routing) Text(l10n.nurTakeoverHint),
          SizedBox(
            height: 44,
            child: FilledButton(
              key: const ValueKey('nur-connect-toggle'),
              onPressed: changing || safeMode || (!running && refusal != null)
                  ? null
                  : _toggle,
              child: changing
                  ? const CommonCircleLoading(size: 20)
                  : Text(running ? l10n.nurDisconnect : l10n.nurConnect),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConnectionCaptureMode { vpn, proxy }

class _ConnectionModeSelector extends ConsumerWidget {
  const _ConnectionModeSelector();

  void _select(WidgetRef ref, _ConnectionCaptureMode mode) {
    if (ref.read(isStartProvider) ||
        ref.read(settingLockedProvider('clash.tun.enable')) ||
        mode == _ConnectionCaptureMode.proxy &&
            !ref.read(systemProxyAllowedProvider)) {
      return;
    }
    final vpn = mode == _ConnectionCaptureMode.vpn;
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith.tun(enable: vpn));
    ref
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(systemProxy: !vpn));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final vpn = ref.watch(patchClashConfigProvider.select((s) => s.tun.enable));
    final proxy = ref.watch(
      networkSettingProvider.select((s) => s.systemProxy),
    );
    final running = ref.watch(isStartProvider);
    final locked = ref.watch(settingLockedProvider('clash.tun.enable'));
    final unavailable =
        running ||
        locked ||
        ref.watch(coreStatusProvider) == CoreStatus.connecting;
    final selected = <_ConnectionCaptureMode>{
      if (vpn)
        _ConnectionCaptureMode.vpn
      else if (proxy)
        _ConnectionCaptureMode.proxy,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Semantics(
          label: l10n.nurConnectionMode,
          child: SegmentedButton<_ConnectionCaptureMode>(
            key: const ValueKey('nur-connection-mode'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment(
                value: _ConnectionCaptureMode.vpn,
                icon: const GlyphIcon(AppGlyphs.vpn),
                label: const Text('VPN (TUN)'),
                tooltip: l10n.nurVpnDescription,
              ),
              ButtonSegment(
                value: _ConnectionCaptureMode.proxy,
                enabled: ref.watch(systemProxyAllowedProvider),
                icon: const GlyphIcon(AppGlyphs.shuffle),
                label: Text(l10n.nurProxyMode),
                tooltip: l10n.nurProxyDescription,
              ),
            ],
            selected: selected,
            onSelectionChanged: unavailable
                ? null
                : (values) {
                    if (values.isNotEmpty) _select(ref, values.single);
                  },
          ),
        ),
        if (locked || running)
          Text(
            locked ? l10n.managedByProvider : l10n.nurDisconnectToChangeMode,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final group = nurConnectServerGroups(
      ref.watch(currentGroupsStateProvider).value,
      ref.watch(patchClashConfigProvider.select((s) => s.mode)),
    ).panelServerGroup(ref.watch(currentProfileProvider)?.headers.serverGroup);
    final selected = group == null
        ? null
        : ref.watch(selectedProxyNameProvider(group.name));
    return DashboardCard(
      key: const ValueKey('nur-selected-server'),
      onTap: group == null
          ? null
          : () => showProxiesSheet(context, groupName: group.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.proxies,
            title: l10n.server,
            chevron: group != null,
          ),
          EmojiText(
            selected != null &&
                    selected.isNotEmpty &&
                    !isBuiltinOutbound(selected)
                ? selected
                : l10n.nurChooseServer,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.headline.of(context, emphasized: true),
          ),
          if (group == null)
            Text(
              ref.watch(isStartProvider)
                  ? l10n.proxyGroupEmpty
                  : l10n.proxyGroupsAfterStart,
            ),
        ],
      ),
    );
  }
}

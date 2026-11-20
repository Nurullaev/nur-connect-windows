import 'dart:async';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
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
    final simple = ref.watch(simpleModeProvider);
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
          Flexible(
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
                const NetworkTakeoverCard(),
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
                if (!simple) const OutboundModeCard(),
                const NetworkSpeedCard(),
              ],
              if (announcement) const AnnouncementCard(),
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
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          Text(
                            l10n.nurHomeSubtitle,
                            style: AppTextStyle.callout.of(context),
                          ),
                          if (profile != null)
                            TonalButton(
                              glyph: AppGlyphs.cloudDownload,
                              label: l10n.nurAddSubscription,
                              onPressed: () =>
                                  unawaited(addProfileByLink(context, ref)),
                            ),
                        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Row(
            spacing: 14,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: GlyphIcon(
                    AppGlyphs.status,
                    size: 36,
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
                      style: AppTextStyle.title2.of(context, emphasized: true),
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
          if (!routing) Text(l10n.nurTakeoverHint),
          SizedBox(
            height: 56,
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

class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final group = ref
        .watch(currentGroupsStateProvider)
        .value
        .panelServerGroup(
          ref.watch(currentProfileProvider)?.headers.serverGroup,
        );
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
            selected?.isNotEmpty == true ? selected! : '—',
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

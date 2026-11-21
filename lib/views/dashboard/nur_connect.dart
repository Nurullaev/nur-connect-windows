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

/// The Windows home, after the mobile app's design: one large power button,
/// then the subscription and the chosen server. It drives the existing
/// profile, server and connection actions.
class NurConnectDashboard extends ConsumerWidget {
  const NurConnectDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              width: 36,
              height: 36,
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
          const details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [ProfilesCard(), _ServerCard()],
          );
          return DashboardDensityScope(
            // Natural-height cards avoid fixed-height overflow at large text.
            density: DashboardDensity.mobile,
            scale: scale,
            child: SingleChildScrollView(
              key: const PageStorageKey('nur-connect-home'),
              padding: EdgeInsets.fromLTRB(
                24,
                12 + context.contentTopPadding,
                24,
                24 + context.bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: twoColumns && profile != null ? 1040 : 560,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      if (announcement) const AnnouncementCard(compact: true),
                      if (profile == null)
                        _WelcomeCard(hasProfiles: hasProfiles)
                      else if (twoColumns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 32,
                          children: [
                            const Expanded(flex: 5, child: _PowerPanel()),
                            Expanded(flex: 6, child: details),
                          ],
                        )
                      else ...[
                        const _PowerPanel(),
                        details,
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
            // The idle button previews the home it leads to.
            ExcludeSemantics(
              child: IgnorePointer(
                child: NurPowerButton(
                  state: NurPowerState.idle,
                  label: l10n.nurAddSubscription,
                  onPressed: null,
                ),
              ),
            ),
            Text(
              l10n.nurWelcomeTitle,
              textAlign: TextAlign.center,
              style: AppTextStyle.title2.of(context, emphasized: true),
            ),
            Text(
              l10n.nurWelcomeHint,
              textAlign: TextAlign.center,
              style: AppTextStyle.callout
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
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

/// The power button with the state, time and speed under it, and the choice
/// between a system-wide VPN and the system proxy.
class _PowerPanel extends ConsumerStatefulWidget {
  const _PowerPanel();

  @override
  ConsumerState<_PowerPanel> createState() => _PowerPanelState();
}

class _PowerPanelState extends ConsumerState<_PowerPanel> {
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
    final colorScheme = context.colorScheme;
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
    final connected = ready && routing;
    final profile = ref.watch(currentProfileProvider);
    final refusal = profile?.accessRefusal;
    // An ended plan only stops a new connection; a running one is left alone.
    final expired =
        refusal == null &&
        !running &&
        (profile?.isExpiredAt(DateTime.now()) ?? false);
    final blocked = refusal != null || expired;
    final headers = profile?.headers;
    final help = refusal != null
        ? (url: headers?.supportUrl ?? headers?.botUrl, label: l10n.support)
        : expired
        ? (url: headers?.renewUrl, label: l10n.renew)
        : null;
    final helpUrl = help?.url;
    final status = refusal != null
        ? subscriptionImportErrorMessage(
            SubscriptionImportException(refusal),
            l10n,
          )
        : expired
        ? l10n.nurSubscriptionEnded
        : changing
        ? l10n.connecting
        : suspended
        ? l10n.suspended
        : connected
        ? l10n.connected
        : l10n.disconnected;
    final muted = AppTextStyle.footnote
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    return Column(
      key: const ValueKey('nur-connection'),
      mainAxisSize: MainAxisSize.min,
      children: [
        NurPowerButton(
          key: const ValueKey('nur-connect-toggle'),
          state: changing
              ? NurPowerState.changing
              : connected
              ? NurPowerState.connected
              : NurPowerState.idle,
          label: running ? l10n.nurDisconnect : l10n.nurConnect,
          caption: ready ? getTimeText(time) : null,
          onPressed: changing || safeMode || (!running && blocked)
              ? null
              : _toggle,
        ),
        const SizedBox(height: 18),
        Text(
          status,
          key: const ValueKey('nur-status'),
          textAlign: TextAlign.center,
          style: AppTextStyle.title3
              .of(context, emphasized: true)
              .copyWith(color: blocked ? colorScheme.error : null),
        ),
        const SizedBox(height: 4),
        if (expired)
          Text(
            l10n.nurRenewToConnect,
            textAlign: TextAlign.center,
            style: muted,
          )
        else if (ready)
          const _SpeedLine()
        else if (!routing)
          Text(l10n.nurTakeoverHint, textAlign: TextAlign.center, style: muted)
        else
          Text(
            running ? l10n.nurDisconnect : l10n.nurConnect,
            textAlign: TextAlign.center,
            style: muted,
          ),
        if (help != null && helpUrl != null) ...[
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('nur-help-action'),
            onPressed: () => dialogs.openUrl(helpUrl),
            child: Text(help.label),
          ),
        ],
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: const _ConnectionModeSelector(),
        ),
      ],
    );
  }
}

class _SpeedLine extends ConsumerWidget {
  const _SpeedLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(
      trafficsProvider.select((state) => state.list.safeLast(const Traffic())),
    );
    return Text(
      '↓ ${latest.down.shortTraffic.show}/s   ↑ ${latest.up.shortTraffic.show}/s',
      key: const ValueKey('nur-speed'),
      textAlign: TextAlign.center,
      style: AppTextStyle.footnote
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
  }
}

enum NurPowerState { idle, changing, connected }

/// A round power button: a dashed ring when idle, a gold arc running while
/// connecting and a lit gold ring once connected.
class NurPowerButton extends StatefulWidget {
  const NurPowerButton({
    super.key,
    required this.state,
    required this.label,
    required this.onPressed,
    this.caption,
  });

  static const size = 196.0;
  static const faceSize = 136.0;

  final NurPowerState state;

  /// What pressing does, for the tooltip and screen readers.
  final String label;

  /// The time connected, shown under the glyph.
  final String? caption;
  final VoidCallback? onPressed;

  @override
  State<NurPowerButton> createState() => _NurPowerButtonState();
}

class _NurPowerButtonState extends State<NurPowerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(NurPowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncSpin();
  }

  void _syncSpin() {
    if (widget.state == NurPowerState.changing) {
      unawaited(_spin.repeat());
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final lit = widget.state == NurPowerState.connected;
    final enabled = widget.onPressed != null;
    final accent = enabled
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.45);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.55),
          radius: 1.05,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: lit ? 0.18 : 0.08),
              colorScheme.surfaceContainerHigh,
            ),
            colorScheme.surfaceContainerLowest,
          ],
        ),
        border: Border.all(
          color: lit ? colorScheme.secondary : colorScheme.outlineVariant,
          width: lit ? 1.5 : 1,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.30),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: SizedBox.square(
        dimension: NurPowerButton.faceSize,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            GlyphIcon(AppGlyphs.power, size: 44, color: accent),
            if (widget.caption != null)
              Text(
                widget.caption!,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurface),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: AppShape.circle,
            mouseCursor: clickableCursor,
            onTap: widget.onPressed,
            child: SizedBox.square(
              dimension: NurPowerButton.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PowerRingPainter(
                        state: widget.state,
                        spin: _spin,
                        accent: colorScheme.primary,
                        soft: colorScheme.secondary,
                        idle: colorScheme.outline,
                      ),
                    ),
                  ),
                  face,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerRingPainter extends CustomPainter {
  _PowerRingPainter({
    required this.state,
    required this.spin,
    required this.accent,
    required this.soft,
    required this.idle,
  }) : super(repaint: spin);

  static const _dashes = 56;

  final NurPowerState state;
  final Animation<double> spin;
  final Color accent;
  final Color soft;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    const step = 2 * math.pi / _dashes;
    switch (state) {
      case NurPowerState.idle:
        final dash = stroke(idle, 1.4);
        for (var index = 0; index < _dashes; index++) {
          canvas.drawArc(rect, index * step, step * 0.45, false, dash);
        }
      case NurPowerState.changing:
        canvas.drawArc(rect, 0, 2 * math.pi, false, stroke(idle, 1.2));
        canvas.drawArc(
          rect,
          spin.value * 2 * math.pi - math.pi / 2,
          math.pi * 0.7,
          false,
          stroke(accent, 3),
        );
      case NurPowerState.connected:
        canvas.drawArc(
          rect,
          0,
          2 * math.pi,
          false,
          stroke(soft.withValues(alpha: 0.35), 1.4),
        );
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 1.5,
          false,
          stroke(accent, 3),
        );
    }
  }

  @override
  bool shouldRepaint(_PowerRingPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.accent != accent ||
      oldDelegate.soft != soft ||
      oldDelegate.idle != idle;
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
    final colorScheme = context.colorScheme;
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
            style: ButtonStyle(
              shape: const WidgetStatePropertyAll(AppShape.full),
              side: WidgetStatePropertyAll(
                BorderSide(color: colorScheme.outlineVariant),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorScheme.primary
                    : colorScheme.surfaceContainer,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
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
            textAlign: TextAlign.center,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// The chosen server as one row, like the selected row of the server list:
/// a gold edge, the name with its flag, and the last measured delay.
class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final group = nurConnectServerGroups(
      ref.watch(currentGroupsStateProvider).value,
      ref.watch(patchClashConfigProvider.select((s) => s.mode)),
    ).panelServerGroup(ref.watch(currentProfileProvider)?.headers.serverGroup);
    final selected = group == null
        ? null
        : ref.watch(selectedProxyNameProvider(group.name));
    final chosen =
        selected != null && selected.isNotEmpty && !isBuiltinOutbound(selected);
    final delay = chosen
        ? ref.watch(delayProvider(proxyName: selected, testUrl: group!.testUrl))
        : null;
    return DashboardCard(
      key: const ValueKey('nur-selected-server'),
      semanticLabel: l10n.server,
      // The gold edge follows the card's rounded corner.
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
      onTap: group == null
          ? null
          : () => showProxiesSheet(context, groupName: group.name),
      child: Row(
        spacing: 14,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: ShapeDecoration(
              color: chosen ? colorScheme.primary : colorScheme.outlineVariant,
              shape: AppShape.xs,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  l10n.server,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                EmojiText(
                  chosen ? selected : l10n.nurChooseServer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.headline.of(context),
                ),
                if (group == null)
                  Text(
                    ref.watch(isStartProvider)
                        ? l10n.proxyGroupEmpty
                        : l10n.proxyGroupsAfterStart,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (delay != null)
            Text(
              delay < 0 ? l10n.timeout : '$delay ms',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.delayColor(delay)),
            ),
          if (group != null)
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: 20,
              color: colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

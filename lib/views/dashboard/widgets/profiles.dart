import 'dart:async';

import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:fl_clash/views/profiles/custom/custom.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'profile_detail.dart';

typedef _Usage = ({int used, int total, double share});

_Usage? _usageOf(Profile? profile) {
  final info = profile?.subscriptionInfo;
  if (info == null || info.total <= 0) {
    return null;
  }
  final used = info.upload + info.download;
  return (
    used: used,
    total: info.total,
    share: (used / info.total).clamp(0.0, 1.0).toDouble(),
  );
}

DateTime? _expiryOf(Profile? profile) {
  final expire = profile?.subscriptionInfo?.expire ?? 0;
  return expire > 0 ? DateTime.fromMillisecondsSinceEpoch(expire * 1000) : null;
}

/// Counts down in days, then hours, then minutes, never reaching zero
/// before the plan actually ends.
String _timeLeftText(BuildContext context, Duration left) {
  final appLocalizations = context.appLocalizations;
  if (left.inDays >= 1) {
    return appLocalizations.profileDaysFigure(left.inDays);
  }
  if (left.inHours >= 1) {
    return appLocalizations.profileHoursFigure(left.inHours);
  }
  return appLocalizations.profileMinutesFigure(math.max(1, left.inMinutes));
}

void _openProfile(BuildContext context, WidgetRef ref, Profile? profile) {
  switch (profile) {
    case null:
      unawaited(addProfileByLink(context, ref));
    case Profile(type: ProfileType.custom, :final id):
      showCustomProfileSheet(context, id);
    case _:
      showProfileDetailSheet(context);
  }
}

/// The same confirmation the profiles page asks before it deletes.
Future<void> _deleteProfile(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final profilesAction = ref.read(profilesActionProvider.notifier);
  final appLocalizations = context.appLocalizations;
  final users = await profilesAction.providerUsers(profile);
  final confirmed = await dialogs.showMessage(
    title: appLocalizations.tip,
    message: TextSpan(
      text: users.isEmpty
          ? appLocalizations.deleteTip(appLocalizations.profile)
          : appLocalizations.providerInUse(
              profile.realLabel,
              users.map((item) => item.realLabel).join(', '),
            ),
    ),
    destructive: true,
    confirmText: appLocalizations.delete,
  );
  if (confirmed != true) return;
  await profilesAction.deleteProfile(profile.id);
}

const _nearlyUsedShare = 0.9;

/// The name row already carries the way to other profiles, so the header
/// keeps only the panel's links and gives them the room it saves.
const _actionGlyphSize = 22.0;

const _soonDays = 7;

class ProfilesCard extends ConsumerWidget {
  const ProfilesCard({super.key, this.dense = false, this.footer = const []});

  /// One header row carrying the profile's name, with the plan figures right
  /// under it: the Nur Connect home keeps the card low.
  final bool dense;

  /// Rows the dense card shows under the plan, each after a thin rule: the
  /// panel's promotion and announcement share the card, as in Happ.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = DashboardDensityScope.of(context);
    final mobile = !density.isDesktop;
    final compact = density.isCompact;
    final appLocalizations = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final offers = ref.watch(profileOffersProvider);
    final switchable = ref.watch(
      profilesProvider.select((profiles) => profiles.length > 1),
    );
    final usage = _usageOf(profile);
    final expiry = _expiryOf(profile);
    final figure = mobile
        ? AppTextStyle.title3
        : (compact ? AppTextStyle.callout : AppTextStyle.headline);
    final name = mobile || !compact
        ? AppTextStyle.headline
        : AppTextStyle.callout;
    final sync = profile != null && profile.type == ProfileType.url
        ? _SyncButton(key: ValueKey(profile.id), profile: profile)
        : null;
    // Provider links, in this order: site (the provider's web cabinet from
    // account-url), bot, subscription page (profile-web-page-url), support.
    final siteUrl = profile?.headers.accountUrl;
    final site = siteUrl == null
        ? null
        : DashboardIconButton(
            key: const ValueKey('profile-site'),
            glyph: AppGlyphs.globe,
            tooltip: appLocalizations.website,
            iconSize: _actionGlyphSize,
            onPressed: () => dialogs.openUrl(siteUrl),
          );
    final subscriptionPageUrl = profile?.headers.webPageUrl;
    final subscriptionPage = subscriptionPageUrl == null
        ? null
        : DashboardIconButton(
            key: const ValueKey('profile-subscription-page'),
            glyph: AppGlyphs.link,
            tooltip: appLocalizations.nurSubscriptionPage,
            iconSize: _actionGlyphSize,
            onPressed: () => dialogs.openUrl(subscriptionPageUrl),
          );
    final botUrl = profile?.headers.botUrl;
    final bot = botUrl == null
        ? null
        : DashboardIconButton(
            key: const ValueKey('profile-bot'),
            glyph: AppGlyphs.send,
            tooltip: appLocalizations.nurBot,
            iconSize: _actionGlyphSize,
            onPressed: () => dialogs.openUrl(botUrl),
          );
    final supportUrl = profile?.headers.supportUrl;
    final support = supportUrl == null
        ? null
        : DashboardIconButton(
            glyph: AppGlyphs.support,
            tooltip: appLocalizations.support,
            iconSize: _actionGlyphSize,
            onPressed: () => dialogs.openUrl(supportUrl),
          );
    final swap = profile != null && switchable
        ? SizedBox(
            height: name.leading,
            child: DashboardIconButton(
              glyph: AppGlyphs.swap,
              tooltip: appLocalizations.switchProfile,
              onPressed: () => showProfilesSheet(context),
            ),
          )
        : null;
    final hasFigures =
        profile != null &&
        (expiry != null || usage != null || offers.isNotEmpty);
    if (dense) {
      final more = profile == null
          ? null
          : CommonPopupBox(
              targetBuilder: (open) => DashboardIconButton(
                key: const ValueKey('profile-more'),
                glyph: AppGlyphs.more,
                tooltip: appLocalizations.more,
                iconSize: _actionGlyphSize,
                onPressed: open,
              ),
              popupBuilder: (_) => CommonPopupMenu(
                items: [
                  CommonPopupMenuItem(
                    glyph: AppGlyphs.info,
                    label: appLocalizations.profileDetails,
                    onPressed: () => _openProfile(context, ref, profile),
                  ),
                  CommonPopupMenuItem(
                    danger: true,
                    glyph: AppGlyphs.delete,
                    label: appLocalizations.delete,
                    onPressed: () =>
                        unawaited(_deleteProfile(context, ref, profile)),
                  ),
                ],
              ),
            );
      final rule = Divider(
        height: 1,
        thickness: 1,
        color: DashboardColors.of(context).tone2,
      );
      return DashboardCard(
        key: const ValueKey('profile-card-dense'),
        semanticLabel: appLocalizations.profile,
        onTap: () => _openProfile(context, ref, profile),
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  AppGlyphs.profiles,
                  size: DashboardCardHeader.glyphSize,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: EmojiText(
                          profile?.realLabel ?? appLocalizations.addProfile,
                          key: const ValueKey('profile-card-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.headline.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      ?swap,
                    ],
                  ),
                ),
                ?site,
                ?bot,
                ?subscriptionPage,
                ?support,
                ?sync,
                ?more,
              ],
            ),
            if (hasFigures) ...[
              const SizedBox(height: 10),
              _PlanFigures(
                expiry: expiry,
                usage: usage,
                offers: offers,
                figure: AppTextStyle.headline,
                gap: 6,
              ),
            ],
            for (final row in footer) ...[
              const SizedBox(height: 12),
              rule,
              const SizedBox(height: 10),
              row,
            ],
          ],
        ),
      );
    }
    final nameRow = Row(
      children: [
        Flexible(
          child: EmojiText(
            profile?.realLabel ?? appLocalizations.addProfile,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: name.of(context, emphasized: true),
          ),
        ),
        ?swap,
      ],
    );
    return DashboardCard(
      semanticLabel: appLocalizations.profile,
      onTap: mobile || profile == null
          ? () => _openProfile(context, ref, profile)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.profiles,
            title: appLocalizations.profile,
            trailing: [?site, ?bot, ?subscriptionPage, ?support, ?sync],
          ),
          SizedBox(height: mobile ? 12 : 10),
          nameRow,
          if (hasFigures) ...[
            if (mobile) const SizedBox(height: 14) else const Spacer(),
            _PlanFigures(
              expiry: expiry,
              usage: usage,
              offers: offers,
              figure: figure,
              gap: mobile ? 8 : 6,
            ),
          ],
        ],
      ),
    );
  }
}

const _rowGap = 12.0;

/// Spins while the update runs and shows a green check for a moment once
/// it went through.
class _SyncButton extends ConsumerStatefulWidget {
  const _SyncButton({super.key, required this.profile});

  static const doneDuration = Duration(seconds: 1);
  static const switchDuration = Duration(milliseconds: 150);

  final Profile profile;

  @override
  ConsumerState<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<_SyncButton> {
  Timer? _doneTimer;

  @override
  void dispose() {
    _doneTimer?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    final done = await syncProfile(ref, widget.profile);
    if (!done || !mounted) {
      return;
    }
    setState(() {
      _doneTimer?.cancel();
      _doneTimer = Timer(_SyncButton.doneDuration, () {
        if (mounted) {
          setState(() => _doneTimer = null);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isUpdating = ref.watch(
      isUpdatingProvider(widget.profile.updatingKey),
    );
    final done = _doneTimer != null;
    final Widget child = isUpdating
        ? const SizedBox.square(
            key: ValueKey('updating'),
            dimension: 32,
            child: Center(child: CommonCircleLoading(size: 18)),
          )
        : DashboardIconButton(
            key: ValueKey(done),
            glyph: done ? AppGlyphs.check : AppGlyphs.sync,
            tooltip: appLocalizations.update,
            iconSize: _actionGlyphSize,
            color: done ? context.colorScheme.success : null,
            onPressed: _sync,
          );
    return AnimatedSwitcher(
      duration: context.motionDuration(_SyncButton.switchDuration),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: child,
    );
  }
}

/// How long the plan runs and how much of it is left, the traffic on a
/// bar under them.
class _PlanFigures extends StatefulWidget {
  const _PlanFigures({
    required this.expiry,
    required this.usage,
    required this.offers,
    required this.figure,
    required this.gap,
  });

  final DateTime? expiry;
  final _Usage? usage;
  final List<ProfileOffer> offers;
  final AppTextStyle figure;
  final double gap;

  @override
  State<_PlanFigures> createState() => _PlanFiguresState();
}

class _PlanFiguresState extends State<_PlanFigures> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_PlanFigures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiry != widget.expiry) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The time left reads in whole days, hours or minutes, so it next changes
  /// once the part of its unit beyond the shown count has run out.
  void _schedule() {
    _tick?.cancel();
    _tick = null;
    final left = widget.expiry?.difference(DateTime.now());
    if (left == null || left.isNegative) {
      return;
    }
    final unit = left.inDays >= 1
        ? const Duration(days: 1)
        : left.inHours >= 1
        ? const Duration(hours: 1)
        : const Duration(minutes: 1);
    final rest = Duration(
      microseconds: left.inMicroseconds % unit.inMicroseconds,
    );
    _tick = Timer(rest + const Duration(milliseconds: 1), () {
      if (mounted) {
        setState(_schedule);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colors = DashboardColors.of(context);
    final expiry = widget.expiry;
    final usage = widget.usage;
    final offers = widget.offers;
    final figure = widget.figure;
    final gap = widget.gap;
    final left = expiry?.difference(DateTime.now());
    final expired = left != null && left.isNegative;
    final soon = left != null && left.inDays <= _soonDays;
    final nearlyUsed = usage != null && usage.share >= _nearlyUsedShare;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expiry != null || usage != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _rowGap,
            children: [
              Expanded(
                child: _Figure(
                  value: left == null
                      ? appLocalizations.profileNoExpiry
                      : expired
                      ? appLocalizations.profileExpired
                      : _timeLeftText(context, left),
                  label: expiry == null
                      ? null
                      : appLocalizations.profileUntil(expiry.showDate),
                  tone: expired || soon ? colors.warn : null,
                  figure: figure,
                ),
              ),
              Expanded(
                child: _Figure(
                  value: usage == null
                      ? appLocalizations.profileTrafficUnlimited
                      : dashboardQuota(math.max(0, usage.total - usage.used)),
                  label: usage == null
                      ? null
                      : appLocalizations.profileLeftOfTotal(
                          dashboardQuota(usage.total),
                        ),
                  tone: nearlyUsed ? colors.warn : null,
                  figure: figure,
                  end: true,
                ),
              ),
            ],
          ),
        if (usage != null) ...[
          SizedBox(height: gap),
          _UsageBar(
            value: usage.share,
            active: nearlyUsed ? colors.warn : context.colorScheme.primary,
            track: colors.tone2,
          ),
        ],
        if (offers.isNotEmpty) ...[
          SizedBox(height: gap + 4),
          Row(
            spacing: 8,
            children: [
              for (final offer in offers)
                Expanded(child: _OfferButton(offer: offer)),
            ],
          ),
        ],
      ],
    );
  }
}

/// The panel's link to renew or top up, behind the external link prompt,
/// filled like the start button.
class _OfferButton extends StatelessWidget {
  const _OfferButton({required this.offer});

  final ProfileOffer offer;

  static const height = 32.0;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final label = switch (offer.kind) {
      ProfileOfferKind.buyPlan => appLocalizations.buyPlan,
      ProfileOfferKind.buyTraffic => appLocalizations.buyTraffic,
    };
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: () => dialogs.openUrl(offer.url),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: AppTextStyle.footnote.of(context, emphasized: true),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.tone,
    required this.figure,
    this.end = false,
  });

  final String value;
  final String? label;
  final Color? tone;
  final AppTextStyle figure;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final alignment = end
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    final label = this.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            value,
            maxLines: 1,
            style: DashboardText.figure(
              context,
              figure,
              color: tone,
            ).copyWith(letterSpacing: 0),
          ),
        ),
        if (label != null)
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: end ? TextAlign.end : TextAlign.start,
            style: DashboardText.label(context),
          ),
      ],
    );
  }
}

/// A pill track with the used share filled from the start.
class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.value,
    required this.active,
    required this.track,
  });

  final double value;
  final Color active;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRSuperellipse(
      borderRadius: AppRadius.full,
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: track,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              heightFactor: 1,
              child: ClipRSuperellipse(
                borderRadius: AppRadius.full,
                child: ColoredBox(color: active),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

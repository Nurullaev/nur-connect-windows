import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';

final _linkPattern = RegExp(r'https?://[^\s<>"]+');

const _linkTrailing = '.,;:!?)';

/// What the subscription announced in its `announce` header, its links
/// opening after the external link prompt.
class AnnouncementCard extends ConsumerStatefulWidget {
  const AnnouncementCard({
    super.key,
    this.compact = false,
    this.inline = false,
  });

  /// A low card for the Windows home: the icon beside the text instead of a
  /// header, smaller type and the panel's blank lines dropped.
  final bool compact;

  /// The compact row alone, to sit inside another card.
  final bool inline;

  @override
  ConsumerState<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<AnnouncementCard> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _spanOf(String text, TextStyle style, Color linkColor) {
    _disposeRecognizers();
    final linkStyle = style.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );
    final children = <InlineSpan>[];
    var at = 0;
    for (final match in _linkPattern.allMatches(text)) {
      var end = match.end;
      while (end > match.start && _linkTrailing.contains(text[end - 1])) {
        end--;
      }
      final url = text.substring(match.start, end);
      if (match.start > at) {
        children.add(EmojiText.spanOf(text.substring(at, match.start), style));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => dialogs.openUrl(url);
      _recognizers.add(recognizer);
      children.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      at = end;
    }
    if (at < text.length) {
      children.add(EmojiText.spanOf(text.substring(at), style));
    }
    return TextSpan(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final text = ref.watch(announcementProvider);
    if (text == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    if (widget.compact || widget.inline) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: GlyphIcon(
              AppGlyphs.info,
              size: 16,
              color: colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text.rich(
              _spanOf(
                compactAnnouncement(text),
                AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurface),
                colorScheme.primary,
              ),
            ),
          ),
        ],
      );
      if (widget.inline) {
        return Semantics(
          key: const ValueKey('announcement-inline'),
          container: true,
          label: appLocalizations.announcement,
          child: row,
        );
      }
      return DashboardCard(
        key: const ValueKey('announcement-compact'),
        semanticLabel: appLocalizations.announcement,
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        child: row,
      );
    }
    final style = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colorScheme.onSurface);
    return DashboardCard(
      semanticLabel: appLocalizations.announcement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.info,
            title: appLocalizations.announcement,
          ),
          const SizedBox(height: 8),
          Text.rich(_spanOf(text, style, colorScheme.primary)),
        ],
      ),
    );
  }
}

/// [text] without its blank lines and the spaces around each line.
String compactAnnouncement(String text) => text
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

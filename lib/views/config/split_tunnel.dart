import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Reads the processes behind the Core's current connections.
typedef SplitTunnelConnectionsReader = Future<List<TrackerInfo>> Function();

void _update(
  WidgetRef ref,
  SplitTunnelProps Function(SplitTunnelProps props) change,
) {
  ref
      .read(networkSettingProvider.notifier)
      .update(
        (state) => state.copyWith(splitTunnel: change(state.splitTunnel)),
      );
}

/// Adds [name] once: Windows file names ignore case.
void _add(WidgetRef ref, String name) {
  _update(ref, (props) {
    final taken = {for (final app in props.apps) app.toLowerCase()};
    if (taken.contains(name.toLowerCase())) return props;
    return props.copyWith(apps: [...props.apps, name]);
  });
}

String _modeLabel(AppLocalizations l10n, SplitTunnelMode mode) =>
    switch (mode) {
      SplitTunnelMode.onlySelected => l10n.splitTunnelOnlySelected,
      SplitTunnelMode.exceptSelected => l10n.splitTunnelExceptSelected,
    };

/// The settings entry, its subtitle telling what the split tunnel does now.
class SplitTunnelItem extends ConsumerWidget {
  const SplitTunnelItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final props = ref.watch(
      networkSettingProvider.select((state) => state.splitTunnel),
    );
    final apps = splitTunnelApps(props);
    final subtitle = !props.enabled
        ? l10n.splitTunnelOff
        : apps.isEmpty
        ? l10n.splitTunnelNoApps
        : '${_modeLabel(l10n, props.mode)} · ${l10n.itemsCount(apps.length)}';
    return ListItem.open(
      key: const ValueKey('split-tunnel-item'),
      leading: const GlyphIcon(AppGlyphs.split),
      title: Text(l10n.splitTunnel),
      subtitle: Text(subtitle),
      widget: const SplitTunnelView(),
    );
  }
}

class SplitTunnelView extends ConsumerWidget {
  const SplitTunnelView({super.key, this.connectionsReader});

  @visibleForTesting
  final SplitTunnelConnectionsReader? connectionsReader;

  Future<void> _pickFile(WidgetRef ref) async {
    final file = await globalState.safeRun(
      () => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['exe'],
      ),
      silence: false,
    );
    if (file == null) return;
    final name = splitTunnelAppName(file.path ?? file.name);
    if (name != null) _add(ref, name);
  }

  Future<void> _typeName(BuildContext context, WidgetRef ref) async {
    final l10n = context.appLocalizations;
    final typed = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: l10n.splitTunnelAddByName,
        value: '',
        labelText: l10n.splitTunnelAppLabel,
        hintText: 'chrome.exe',
        validator: (value) => splitTunnelAppName(value ?? '') == null
            ? l10n.splitTunnelInvalidName
            : null,
      ),
    );
    final name = typed == null ? null : splitTunnelAppName(typed);
    if (name != null) _add(ref, name);
  }

  Future<void> _pickRunning(BuildContext context, WidgetRef ref) async {
    final l10n = context.appLocalizations;
    final reader =
        connectionsReader ?? ref.read(coreHandlerProvider).getConnections;
    final infos = await globalState.safeRun(reader) ?? const <TrackerInfo>[];
    final taken = {
      for (final app in ref.read(networkSettingProvider).splitTunnel.apps)
        app.toLowerCase(),
    };
    final names = <String, String>{};
    for (final info in infos) {
      final name = splitTunnelAppName(
        info.metadata.process.isNotEmpty
            ? info.metadata.process
            : info.metadata.processPath,
      );
      if (name == null || taken.contains(name.toLowerCase())) continue;
      names.putIfAbsent(name.toLowerCase(), () => name);
    }
    final sorted = names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!context.mounted) return;
    if (sorted.isEmpty) {
      await dialogs.showAlert(
        title: l10n.splitTunnelFromConnections,
        message: TextSpan(text: l10n.splitTunnelNoConnections),
      );
      return;
    }
    final picked = await dialogs.showCommonDialog<String>(
      child: _RunningAppsDialog(names: sorted),
    );
    if (picked != null) _add(ref, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final props = ref.watch(
      networkSettingProvider.select((state) => state.splitTunnel),
    );
    final apps = props.apps;
    return CommonScaffold(
      title: l10n.splitTunnel,
      body: ListView(
        key: const PageStorageKey('split-tunnel'),
        padding: EdgeInsets.fromLTRB(
          16,
          context.sectionsTopPadding,
          16,
          24 + context.bottomInset,
        ),
        children: [
          generateSection(
            items: [
              ListItem.toggle(
                key: const ValueKey('split-tunnel-enabled'),
                title: Text(l10n.splitTunnelEnable),
                value: props.enabled,
                onChanged: (value) =>
                    _update(ref, (props) => props.copyWith(enabled: value)),
              ),
              ListItem<SplitTunnelMode>.options(
                key: const ValueKey('split-tunnel-mode'),
                title: Text(l10n.splitTunnelMode),
                options: SplitTunnelMode.values,
                value: props.mode,
                textBuilder: (mode) => _modeLabel(l10n, mode),
                onChanged: (mode) =>
                    _update(ref, (props) => props.copyWith(mode: mode)),
              ),
            ],
            footer: l10n.splitTunnelDesc,
          ),
          generateSection(
            title: l10n.splitTunnelApps,
            items: [
              for (final app in apps)
                ListItem(
                  key: ValueKey('split-tunnel-app-$app'),
                  leading: const GlyphIcon(AppGlyphs.appsList),
                  title: Text(
                    app,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const GlyphIcon(AppGlyphs.delete),
                    onPressed: () => _update(
                      ref,
                      (props) => props.copyWith(
                        apps: [
                          for (final item in props.apps)
                            if (item != app) item,
                        ],
                      ),
                    ),
                  ),
                ),
              ListItem(
                key: const ValueKey('split-tunnel-add-file'),
                leading: const GlyphIcon(AppGlyphs.add),
                title: Text(l10n.splitTunnelAddFile),
                onTap: () => unawaited(_pickFile(ref)),
              ),
              ListItem(
                key: const ValueKey('split-tunnel-add-running'),
                leading: const GlyphIcon(AppGlyphs.connections),
                title: Text(l10n.splitTunnelFromConnections),
                onTap: () => unawaited(_pickRunning(context, ref)),
              ),
              ListItem(
                key: const ValueKey('split-tunnel-add-name'),
                leading: const GlyphIcon(AppGlyphs.edit),
                title: Text(l10n.splitTunnelAddByName),
                onTap: () => unawaited(_typeName(context, ref)),
              ),
            ],
            footer: apps.isEmpty
                ? l10n.splitTunnelEmptyHint
                : l10n.splitTunnelAppsHint,
          ),
        ],
      ),
    );
  }
}

class _RunningAppsDialog extends StatelessWidget {
  const _RunningAppsDialog({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return CommonDialog(
      title: l10n.splitTunnelFromConnections,
      padding: EdgeInsets.zero,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final name in names)
              ListTile(
                key: ValueKey('split-tunnel-running-$name'),
                title: Text(name),
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
      ),
    );
  }
}

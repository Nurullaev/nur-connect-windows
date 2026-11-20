import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:fl_clash/views/config/advanced.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/hotkey.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Windows essentials, backed by the same persisted/managed settings as the
/// engine, tray and startup manager. Advanced pages remain available separately.
class NurWindowsSettings extends ConsumerWidget {
  const NurWindowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.appLocalizations;
    final simple = ref.watch(simpleModeProvider);
    final locale = ref.watch(
      appSettingProvider.select((state) => state.locale),
    );
    return CommonScaffold(
      title: l10n.settings,
      body: ListView(
        key: const PageStorageKey('nur-windows-settings'),
        padding: EdgeInsets.fromLTRB(
          16,
          context.sectionsTopPadding,
          16,
          24 + context.bottomInset,
        ),
        children: [
          const ManagedSettingsHint(keys: generalPageKeys),
          generateSection(
            title: l10n.connection,
            items: const [TUNItem(), SystemProxyItem()],
            footer: l10n.tunDesc,
          ),
          generateSection(
            title: l10n.startupAndBackground,
            items: [
              ConfigToggleItem(
                title: (l) => l.autoLaunch,
                managedKey: 'app.autoLaunch',
                selector: appSettingProvider.select(
                  (state) => state.autoLaunch,
                ),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(autoLaunch: value)),
              ),
              ConfigToggleItem(
                title: (l) => l.silentLaunch,
                managedKey: 'app.silentLaunch',
                selector: appSettingProvider.select(
                  (state) => state.silentLaunch,
                ),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(silentLaunch: value)),
              ),
              ConfigToggleItem(
                title: (l) => l.autoRun,
                managedKey: 'app.autoRun',
                selector: appSettingProvider.select((state) => state.autoRun),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(autoRun: value)),
              ),
              ConfigToggleItem(
                title: (l) => l.minimizeOnExit,
                managedKey: 'app.minimizeOnExit',
                selector: appSettingProvider.select(
                  (state) => state.minimizeOnExit,
                ),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(minimizeOnExit: value)),
              ),
            ],
            footer: '${l10n.silentLaunchDesc}\n${l10n.autoRunDesc}',
          ),
          generateSection(
            title: l10n.theme,
            items: [
              ListItem<Locale?>.options(
                leading: const GlyphIcon(AppGlyphs.language),
                title: Text(l10n.language),
                options: [null, ...AppLocalizations.delegate.supportedLocales],
                value: getLocaleForString(locale),
                textBuilder: (value) => value?.label ?? l10n.defaultText,
                onChanged: (value) => ref
                    .read(appSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(locale: value?.toString()),
                    ),
              ),
              ConfigOptionsItem<ThemeMode>(
                title: (l) => l.themeMode,
                managedKey: 'view.app.theme',
                options: ThemeMode.values,
                selector: themeSettingProvider.select(
                  (state) => state.themeMode,
                ),
                textBuilder: (mode) => switch (mode) {
                  ThemeMode.system => l10n.auto,
                  ThemeMode.light => l10n.light,
                  ThemeMode.dark => l10n.dark,
                },
                onChanged: (ref, value) => ref
                    .read(themeSettingProvider.notifier)
                    .update((state) => state.copyWith(themeMode: value)),
              ),
              ListItem.open(title: Text(l10n.theme), widget: const ThemeView()),
            ],
          ),
          generateSection(
            title: l10n.update,
            items: [
              ConfigToggleItem(
                title: (l) => l.autoCheckUpdate,
                managedKey: 'app.autoCheckUpdate',
                selector: appSettingProvider.select((s) => s.autoCheckUpdate),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((s) => s.copyWith(autoCheckUpdate: value)),
              ),
              ListItem(
                title: Text(l10n.checkUpdate),
                onTap: () async => checkAppUpdates(context, ref),
              ),
            ],
            footer: l10n.nurUpdatesHint,
          ),
          generateSection(
            title: l10n.profiles,
            items: [
              ListItem.open(
                title: Text(l10n.profiles),
                widget: const ProfilesView(),
              ),
              ListItem.open(
                title: Text(l10n.backupAndRestore),
                widget: const BackupAndRestore(),
              ),
            ],
          ),
          generateSection(
            title: l10n.logsAndDiagnostics,
            items: const [OpenLogsFolderItem(), ShareLogsItem()],
          ),
          if (!simple)
            generateSection(
              title: l10n.advancedConfig,
              items: [
                ListItem.open(
                  title: Text(l10n.general),
                  widget: const GeneralView(),
                ),
                ListItem.open(
                  title: Text(l10n.advancedConfig),
                  widget: const AdvancedConfigView(),
                ),
                ListItem.open(
                  title: Text(l10n.hotkeyManagement),
                  widget: const HotKeyView(),
                ),
              ],
            ),
          generateSection(
            items: [
              ListItem.open(
                leading: const GlyphIcon(AppGlyphs.info),
                title: Text(l10n.about),
                widget: const AboutView(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

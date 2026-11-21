import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/nur_connect_servers.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'common.dart';

/// Search belongs to this view, so closing a picker never changes another
/// server page's query. Selection and its rollback still use ProxiesAction.
class NurServersView extends ConsumerStatefulWidget {
  const NurServersView({super.key, this.picker = false});

  final bool picker;

  @override
  ConsumerState<NurServersView> createState() => _NurServersViewState();
}

class _NurServersViewState extends ConsumerState<NurServersView> {
  final _search = TextEditingController();
  bool _testing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _test(List<Proxy> proxies, String? url) async {
    if (_testing || proxies.isEmpty) return;
    setState(() => _testing = true);
    try {
      await globalState.safeRun(
        () => ref.read(proxiesActionProvider.notifier).delayTest(proxies, url),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    final profile = ref.watch(currentProfileProvider);
    final style = ref.watch(proxiesStyleSettingProvider);
    var groups = nurConnectServerGroups(
      ref.watch(visibleGroupsStateProvider).value,
      ref.watch(patchClashConfigProvider.select((s) => s.mode)),
    );
    if (ref.watch(oneGroupProvider)) {
      final server = groups.panelServerGroup(profile?.headers.serverGroup);
      groups = server == null ? [] : [server];
    }
    final sorted = computeSort(
      groups: groups,
      sortType: style.sortType,
      delayMap: ref.watch(delayDataSourceProvider),
      selectedMap: ref.watch(selectedMapProvider),
      defaultTestUrl: ref.watch(realTestUrlProvider(null)),
    );
    final group =
        sorted.firstWhereOrNull(
          (item) => item.name == profile?.currentGroupName,
        ) ??
        sorted.panelServerGroup(profile?.headers.serverGroup);
    final proxies =
        group?.all
            .where((proxy) => !isBuiltinOutbound(proxy.name))
            .whereMatches(
              SearchQuery(_search.text),
              (proxy) => proxy.searchFields,
            )
            .toList() ??
        const <Proxy>[];
    final alive = ref.watch(coreStatusProvider) == CoreStatus.connected;
    return CommonScaffold(
      title: l10n.nurServers,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.bolt,
          tooltip: l10n.delayTest,
          isLoading: _testing,
          onPressed: !alive || _testing || proxies.isEmpty
              ? null
              : () => _test(proxies, group?.testUrl),
        ),
        IconButtonData(
          glyph: AppGlyphs.sliders,
          tooltip: l10n.settings,
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => CommonScaffold(
              title: l10n.settings,
              body: const _ServerOptions(),
            ),
          ),
        ),
      ],
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12 + context.contentTopPadding,
                16,
                12,
              ),
              child: Column(
                spacing: 12,
                children: [
                  if (sorted.length > 1)
                    DropdownButtonFormField<String>(
                      key: ValueKey((profile?.id, group?.name)),
                      initialValue: group?.name,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.proxyGroup),
                      items: [
                        for (final item in sorted)
                          DropdownMenuItem(
                            value: item.name,
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(proxiesActionProvider.notifier)
                              .updateCurrentGroupName(value);
                        }
                      },
                    ),
                  TextField(
                    key: const ValueKey('nur-server-search'),
                    controller: _search,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.search,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const GlyphIcon(AppGlyphs.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.clearSearch,
                              icon: const GlyphIcon(AppGlyphs.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Expanded(
              child: proxies.isEmpty || group == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.text.isNotEmpty
                              ? l10n.noSearchResults
                              : profile == null
                              ? l10n.nurWelcomeHint
                              : !ref.watch(isStartProvider)
                              ? l10n.proxyGroupsAfterStart
                              : l10n.proxyGroupEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey((profile?.id, group.name)),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16 + context.bottomInset,
                      ),
                      itemCount: proxies.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => SizedBox(
                        key: ValueKey(proxies[index].name),
                        height: getItemHeight(ProxyCardType.standard),
                        child: ProxyCard(
                          groupName: group.name,
                          groupType: group.type,
                          proxy: proxies[index],
                          type: ProxyCardType.standard,
                          testUrl: group.testUrl,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerOptions extends StatelessWidget {
  const _ServerOptions();

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(16, 16 + context.contentTopPadding, 16, 24),
    children: [
      ConfigOptionsItem<ProxiesSortType>(
        title: (l) => l.sort,
        managedKey: 'view.proxies.sort',
        options: ProxiesSortType.values,
        textBuilder: (value) => switch (value) {
          ProxiesSortType.none => context.appLocalizations.defaultText,
          ProxiesSortType.name => context.appLocalizations.name,
          ProxiesSortType.delay => context.appLocalizations.delay,
        },
        selector: proxiesStyleSettingProvider.select((state) => state.sortType),
        onChanged: (ref, value) => ref
            .read(proxiesStyleSettingProvider.notifier)
            .update((state) => state.copyWith(sortType: value)),
      ),
      ConfigToggleItem(
        title: (l) => l.hideTimeoutProxies,
        managedKey: 'view.proxies.hidetimeout',
        selector: proxiesStyleSettingProvider.select(
          (state) => state.hideTimeoutProxies,
        ),
        onChanged: (ref, value) => ref
            .read(proxiesStyleSettingProvider.notifier)
            .update((state) => state.copyWith(hideTimeoutProxies: value)),
      ),
    ],
  );
}

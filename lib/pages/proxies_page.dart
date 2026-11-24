import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/jelly.dart';
import '../core/logo_cache.dart';
import '../core/ordering.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../widgets/common.dart';
import '../widgets/prism.dart';

enum ProxyTab { groups, providers }

class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {

  bool _testing = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _testUrl = 'https://www.gstatic.com/generate_204';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ProxyTab get _tab =>
      ref.watch(proxyTabProvider) == 1 ? ProxyTab.providers : ProxyTab.groups;
  String? get _openedGroup => ref.watch(proxyOpenedProvider);

  void _setTab(ProxyTab t) {
    ref.read(proxyTabProvider.notifier).set(t == ProxyTab.providers ? 1 : 0);
    ref.read(proxyOpenedProvider.notifier).set(null);
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
  }

  void _setColumns(int v) {
    ref.read(settingsProvider.notifier).patch((x) => x.copyWith(proxyColumns: v));
  }

  Future<void> _select(String group, String name) async {
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) {
      ref.read(demoProvider).select(group, name);
    } else {
      try {
        await ref.read(clientProvider)?.selectProxy(group, name);
      } catch (_) {}
    }
    HapticFeedback.mediumImpact();
    ref.invalidate(proxiesProvider);
  }

  Future<void> _testOne(MihomoProxy node) async {
    final settings = ref.read(settingsProvider);
    ref.read(testingProvider.notifier).add(node.name);
    int? delay;
    if (settings.demoMode) {
      delay = await ref.read(demoProvider).testDelay(node.name);
    } else {
      delay =
          await ref.read(clientProvider)?.testDelay(node.name, url: _testUrl);
    }
    ref.read(testingProvider.notifier).remove(node.name);
    if (delay != null) {
      ref.read(delayOverridesProvider.notifier).set(node.name, delay);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _testGroup(MihomoProxy group) async {
    if (_testing) return;
    setState(() => _testing = true);
    final settings = ref.read(settingsProvider);
    try {
      if (settings.demoMode) {
        final demo = ref.read(demoProvider);
        for (var i = 0; i < group.all.length; i += 8) {
          final batch = group.all.skip(i).take(8).toList();
          final results = await Future.wait(batch.map(demo.testDelay));
          for (var j = 0; j < batch.length; j++) {
            final d = results[j];
            if (d != null) {
              ref.read(delayOverridesProvider.notifier).set(batch[j], d);
            }
          }
          if (!mounted) return;
          setState(() {});
        }
      } else {
        final client = ref.read(clientProvider);
        if (client == null) return;
        final result = await client.testGroupDelay(group.name, url: _testUrl);
        result.forEach((k, v) {
          ref.read(delayOverridesProvider.notifier).set(k, v);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// 分组排序：按设置生效
  List<MihomoProxy> _sortGroups(
    List<MihomoProxy> groups,
    Settings settings,
    Map<String, int> overrides,
    Map<String, MihomoProxy> proxies,
  ) {
    final list = [...groups];
    int delayOf(MihomoProxy g) {
      final n = g.now;
      if (n == null) return 1 << 30;
      return overrides[n] ?? proxies[n]?.delay ?? (1 << 30);
    }

    switch (settings.sortMode) {
      case 'config':
        // 内核返回的字典是按名字排序的，用 GLOBAL.all 还原配置顺序
        final master = proxies['GLOBAL']?.all ?? const <String>[];
        if (master.isEmpty) return list;
        final order = {
          for (var i = 0; i < master.length; i++) master[i]: i,
        };
        list.sort((a, b) {
          final ia = order[a.name] ?? (1 << 20);
          final ib = order[b.name] ?? (1 << 20);
          return ia.compareTo(ib);
        });
        return list;
      case 'nameAsc':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'nameDesc':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'delayAsc':
        list.sort((a, b) => delayOf(a).compareTo(delayOf(b)));
      case 'delayDesc':
        list.sort((a, b) => delayOf(b).compareTo(delayOf(a)));
      default:
        return sortByRank(list, (g) => groupRank(g.name));
    }
    return list;
  }

  List<MihomoProxy> _sortedNodes(
      List<MihomoProxy> nodes, String sort, Map<String, int> overrides) {
    final list = [...nodes];
    int delayOf(MihomoProxy n) => overrides[n.name] ?? n.delay ?? (1 << 30);
    switch (sort) {
      case 'nameAsc':
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'nameDesc':
        list.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'delayAsc':
        list.sort((a, b) => delayOf(a).compareTo(delayOf(b)));
      case 'delayDesc':
        list.sort((a, b) => delayOf(b).compareTo(delayOf(a)));
      case 'config':
        return list;
      default:
        // 默认：规则/信息靠前，区域依次往后
        return sortByRank(list, (n) => nodeRank(n.name));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final proxies = ref.watch(proxiesProvider).value ?? const {};
    final mode = ref.watch(outboundModeProvider);
    final showGlobal = ref.watch(settingsProvider).showGlobalGroup;
    final allGroups = proxies.values.where((p) => p.isGroup).toList();
    final globals = allGroups
        .where((g) => g.name.toUpperCase() == 'GLOBAL')
        .toList();
    var rawGroups = allGroups
        .where((g) => g.name.toUpperCase() != 'GLOBAL')
        .toList();
    final globalVisible = showGlobal && mode == 'global';
    if (!globalVisible) globals.clear();
    final groups = [
      ..._sortGroups(rawGroups, ref.watch(settingsProvider),
          ref.watch(delayOverridesProvider), proxies),
      ...globals, // GLOBAL 永远排最后
    ];

    if (_openedGroup != null && !groups.any((g) => g.name == _openedGroup)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(proxyOpenedProvider.notifier).set(null);
      });
    }
    final opened = _openedGroup == null ? null : proxies[_openedGroup];

    final inNodes = _tab == ProxyTab.groups && opened != null;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!inNodes)
            _header(context, settings,
                showLayout: _tab == ProxyTab.groups),
          Expanded(
            child: _tab == ProxyTab.providers
                ? _ProvidersView(onPickNode: (n) {
                    ref.read(proxyTabProvider.notifier).set(0);
                    ref.read(proxyOpenedProvider.notifier).set(n);
                  })
                : opened == null
                    ? _buildGroupView(context, groups, proxies, settings)
                    : _buildNodes(context, opened, proxies, settings),
          ),
        ],
      ),
    );
  }

  /// 顶部行：搜索框 + 代理组/供应商切换 + 布局切换
  Widget _header(BuildContext context, Settings settings,
      {bool showLayout = true}) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;

    Widget toggle() {
      final isGroups = _tab == ProxyTab.groups;
      return JellyPress(
        haptic: false,
        onTap: () =>
            _setTab(isGroups ? ProxyTab.providers : ProxyTab.groups),
        scaleTo: 0.95,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: s.card,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: s.hairline.withValues(alpha: 0.5), width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGroups ? Icons.layers_rounded : Icons.cloud_rounded,
                size: 15,
                color: cs.primary,
              ),
              const SizedBox(width: 5),
              Text(
                isGroups ? '代理组' : '供应商',
                style: TextStyle(
                  color: s.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.swap_horiz_rounded, size: 13, color: s.textTertiary),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: _tab == ProxyTab.providers ? '供应商' : tr('代理'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _searchField(
                    s, _tab == ProxyTab.providers ? '搜索' : '搜索分组'),
              ),
              const SizedBox(width: 8),
              toggle(),
              if (showLayout) ...[
                const SizedBox(width: 6),
                _LayoutToggle(
                  value: settings.proxyColumns,
                  onChanged: _setColumns,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 分组视图

  Widget _buildGroupView(BuildContext context, List<MihomoProxy> groups,
      Map<String, MihomoProxy> proxies, Settings settings) {
    final s = surfacesOf(context);
    final overrides = ref.watch(delayOverridesProvider);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups.where((g) => g.name.toLowerCase().contains(q)).toList();
    final cols = settings.proxyColumns;
    final sizeFactor = settings.cardHeight.clamp(0.6, 1.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text('${groups.length} 个分组',
              style: TextStyle(color: s.textTertiary, fontSize: 12)),
        ),
        const ConnectionErrorBanner(),
        Expanded(
          child: ref.watch(proxiesProvider).value == null && groups.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.hub_outlined,
                  title: '没有可用的代理组',
                  subtitle: '检查 mihomo 是否在运行，或在设置里填入正确地址',
                )
              : cols == 1
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: JellyEntry(
                          index: i,
                          staggerMs: 20,
                          child: _GroupCard(
                            group: filtered[i],
                            proxies: proxies,
                            overrides: overrides,
                            columns: 1,
                            onTap: (rect) =>
                                _openGroup(filtered[i].name, rect),
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: (cols == 1
                                ? 2.55
                                : (cols == 2 ? 1.45 : 0.98)) *
                            sizeFactor,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => JellyEntry(
                        index: i,
                        staggerMs: 22,
                        child: _GroupCard(
                          group: filtered[i],
                          proxies: proxies,
                          overrides: overrides,
                          columns: cols,
                          onTap: (rect) =>
                              _openGroup(filtered[i].name, rect),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  void _openGroup(String name, Rect origin) {
    ref.read(selectedGroupProvider.notifier).set(name);
    final settings = ref.read(settingsProvider);
    final proxies = ref.read(proxiesProvider).value ?? const {};
    final group = proxies[name];
    final count = group?.all.length ?? 0;
    showExpandingSheet<void>(
      context: context,
      origin: origin,
      heightFactor: _sheetHeightFactor(context, settings, count),
      panelOpacity: settings.sheetGlass
          ? settings.surfaceOpacity.clamp(0.5, 1.0)
          : 1.0,
      glass: settings.sheetGlass,
      blur: settings.sheetBlur,
      originRadius: settings.cardRadius,
      reverseDuration: const Duration(milliseconds: 260),
      builder: (_) => _GroupNodesSheet(groupName: name),
    );
  }

  /// 按节点数量估算悬浮窗高度：一两个节点就小窗，多了才占满
  double _sheetHeightFactor(
    BuildContext context,
    Settings settings,
    int count,
  ) {
    final screen = MediaQuery.of(context).size;
    final cols = settings.proxyColumns.clamp(1, 3);
    final panelW = screen.width - 64;
    final cellW = (panelW - 20 - (cols - 1) * (cols == 2 ? 7.0 : 4.0)) / cols;
    final aspect = cols == 1 ? 3.2 : (cols == 2 ? 2.9 : 2.1);
    final cellH = cellW / aspect + (cols == 1 ? 5 : 4);

    final rows = count <= 0 ? 1 : (count / cols).ceil();
    // 头部（标题/当前节点）+ 列表 + 内边距
    final contentH = 88 + rows * cellH + 18;
    final factor = contentH / screen.height;
    return factor.clamp(0.18, 0.52);
  }

  // ------------------------------------------------------------ 节点视图

  Widget _buildNodes(BuildContext context, MihomoProxy group,
      Map<String, MihomoProxy> proxies, Settings settings) {
    final s = surfacesOf(context);
    final overrides = ref.watch(delayOverridesProvider);
    final testing = ref.watch(testingProvider);
    final q = _query.trim().toLowerCase();
    final cols = settings.proxyColumns;

    var nodes = group.all
        .map((n) => proxies[n])
        .whereType<MihomoProxy>()
        .toList();

    if (settings.hideTimeout) {
      // -1（超时）和 0（不可用）都隐藏；null（未测）保留
      nodes = nodes.where((n) {
        // 子分组永远保留；节点延时 <= 0（超时/0）视为不可用
        if (n.isGroup) return true;
        final d = overrides[n.name] ?? n.delay;
        return d == null || d > 0;
      }).toList();
    }
    if (q.isNotEmpty) {
      nodes = nodes
          .where((n) =>
              n.name.toLowerCase().contains(q) ||
              n.type.toLowerCase().contains(q))
          .toList();
    }
    nodes = _sortedNodes(nodes, settings.nodeSortMode, overrides);

    Widget tile(int i) {
      final n = nodes[i];
      return _NodeTile(
        node: n,
        delay: overrides[n.name] ?? n.delay,
        selected: group.now == n.name,
        isTesting: testing.contains(n.name),
        showType: cols == 1,
        onTap: () => _select(group.name, n.name),
        onTest: () => _testOne(n),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              JellyPress(
                haptic: false,
                onTap: () {
                  ref.read(proxyOpenedProvider.notifier).set(null);
                  setState(() {
                    _query = '';
                    _searchCtrl.clear();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: s.textPrimary),
                ),
              ),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: s.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4),
                ),
              ),
              _LayoutToggle(value: cols, onChanged: _setColumns),
              _SortButton(
                value: settings.nodeSortMode,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .patch((x) => x.copyWith(nodeSortMode: v)),
              ),
              JellyPress(
                haptic: false,
                enabled: !_testing,
                onTap: _testing ? null : () => _testGroup(group),
                scaleTo: 0.82,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: _testing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed_rounded, size: 21),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 190, child: _searchField(s, '搜索节点')),
          ),
        ),
        Expanded(
          child: nodes.isEmpty
              ? _NodeMismatch(
                  groupName: group.name,
                  groupNodeNames: group.all,
                  proxyKeys: proxies.keys.toList(),
                )
              : cols == 1
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: nodes.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: JellyEntry(
                      key: ValueKey('${group.name}-${nodes[i].name}'),
                      index: math.min(i, 14),
                      staggerMs: 16,
                      child: tile(i),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: cols == 2 ? 3.4 : 2.4,
                  ),
                  itemCount: nodes.length,
                  itemBuilder: (context, i) => JellyEntry(
                    key: ValueKey('${group.name}-${nodes[i].name}'),
                    index: math.min(i, 14),
                    staggerMs: 16,
                    child: tile(i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _searchField(AppSurfaces s, String hint) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: s.hairline.withValues(alpha: 0.5), width: 0.6),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: s.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: s.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: s.textTertiary, fontSize: 13),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              child:
                  Icon(Icons.close_rounded, size: 15, color: s.textTertiary),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 布局切换

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final next = value == 3 ? 1 : value + 1;
    final icon = switch (value) {
      1 => Icons.view_list_rounded,
      2 => Icons.grid_view_rounded,
      _ => Icons.apps_rounded,
    };
    final label = switch (value) {
      1 => '列表',
      2 => '两列',
      _ => '三列',
    };
    return JellyPress(
      haptic: false,
      onTap: () => onChanged(next),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: s.hairline.withValues(alpha: 0.5), width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: s.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: s.textSecondary, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 分组卡片

class _GroupLogo extends StatelessWidget {
  const _GroupLogo({required this.proxy, this.size = 30});

  final MihomoProxy proxy;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ProxyLogo(proxy: proxy, size: size);
}

class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({
    required this.group,
    required this.proxies,
    required this.overrides,
    required this.columns,
    required this.onTap,
  });

  final MihomoProxy group;
  final Map<String, MihomoProxy> proxies;
  final Map<String, int> overrides;
  final int columns;
  final void Function(Rect origin) onTap;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  final GlobalKey _key = GlobalKey();

  Rect? _rectOf() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final group = widget.group;
    final nowOverride = ref.watch(nowOverrideProvider)[group.name];
    final now = nowOverride ?? group.now;
    // 内核数据追上后清掉本地覆盖
    if (nowOverride != null && group.now == nowOverride) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(nowOverrideProvider.notifier).sync(group.name, group.now);
      });
    }
    final delay = effectiveDelay(
      group.copyWith(now: now),
      widget.proxies,
      widget.overrides,
    );
    final stats = groupStats(group, widget.proxies, widget.overrides);
    final compact = widget.columns != 1;
    final st = ref.watch(settingsProvider);
    final logoSize = st.proxyLogoSize;
    final cardRadius = st.cardRadius;

    return JellyPress(
      key: _key,
      onTap: () {
        final r = _rectOf();
        if (r != null) widget.onTap(r);
      },
      scaleTo: 0.89,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          compact ? 8 : 14,
          compact ? 12 : 16,
          compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: s.hairline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 名称 + logo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: s.textPrimary,
                      fontSize: (compact ? 14 : 16) *
                              ref.watch(settingsProvider).titleScale,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _GroupLogo(proxy: group, size: logoSize),
              ],
            ),
            const SizedBox(height: 1),
            // 类型 · 可用/总数 · 手动锁定标记
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${_groupTypeLabel(group.type)}'
                    '${stats.total > 0 ? ' · ${stats.available}/${stats.total}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: s.textTertiary, fontSize: 9.5),
                  ),
                ),
                if (_isAutoType(group.type) &&
                    ref.watch(manualGroupsProvider).contains(group.name)) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.lock_rounded, size: 10, color: s.textTertiary),
                ],
              ],
            ),
            const SizedBox(height: 2),
            // 当前节点 + 延时
            Row(
              children: [
                Icon(Icons.subdirectory_arrow_right_rounded,
                    size: 12, color: s.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    now ?? '未选择',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: s.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
                if (_testing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                else
                  _MiniDelay(delay, onTap: _testGroup, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _testing = false;

  /// 点延时角标 → 测整组（/group/{name}/delay 失败时逐个节点测）
  Future<void> _testGroup() async {
    if (_testing) return;
    // 用户重新测速 => 恢复自动选择，先解锁
    ref.read(manualGroupsProvider.notifier).clear(widget.group.name);
    final settings = ref.read(settingsProvider);
    final client = ref.read(clientProvider);
    if (client == null) return;

    var url = settings.delayTestUrl;
    if (settings.delayTestMode != 'app') {
      final provs = ref.read(providersProvider).value ?? const {};
      final configured = provs.values
          .map((p) => p.testUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
      if (configured.isNotEmpty) url = configured.first;
    }

    setState(() => _testing = true);
    var result = <String, int>{};
    try {
      result = await client.testGroupDelay(widget.group.name, url: url);
    } catch (_) {
      result = {};
    }

    // 有些内核/分组不支持整组接口，退化成逐节点测速
    if (result.isEmpty) {
      final proxies = ref.read(providersProvider).value ?? const {};
      final providerOf = <String, String>{};
      for (final e in proxies.entries) {
        for (final n in e.value.proxies) {
          providerOf[n.name] = e.key;
        }
      }
      final nodes = widget.group.all
          .map((n) => widget.proxies[n])
          .whereType<MihomoProxy>()
          .where((n) => !n.isGroup)
          .toList();
      for (final n in nodes) {
        try {
          final prov = providerOf[n.name];
          final d = prov != null
              ? await client.testProviderNode(prov, n.name)
              : await client.testDelay(n.name, url: url);
          if (d != null) result[n.name] = d;
        } catch (_) {
          result[n.name] = -1;
        }
      }
    }

    if (!mounted) return;
    for (final e in result.entries) {
      ref.read(delayOverridesProvider.notifier).set(e.key, e.value);
    }
    setState(() => _testing = false);
  }
}

// ---------------------------------------------------------------- 节点

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.delay,
    required this.selected,
    required this.isTesting,
    required this.onTap,
    required this.onTest,
    required this.showType,
  });

  final MihomoProxy node;
  final int? delay;
  final bool selected;
  final bool isTesting;
  final VoidCallback onTap;
  final VoidCallback onTest;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;

    return JellyPress(
      onTap: onTap,
      onLongPress: onTest,
      scaleTo: 0.975,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: showType ? 14 : 10,
          vertical: showType ? 12 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.08) : s.card,
          borderRadius: BorderRadius.circular(showType ? 16 : 13),
          border: Border.all(
            color:
                selected ? cs.primary.withValues(alpha: 0.55) : Colors.transparent,
            width: 1.3,
          ),
          boxShadow: cardShadow(context),
        ),
        child: showType
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelectDot(selected: selected, color: cs.primary),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: s.textPrimary,
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(node.type,
                                style: TextStyle(
                                    color: s.textTertiary, fontSize: 10.5)),
                            const SizedBox(width: 5),
                            _MiniTag(ipFamilyOf(node)),
                            if (node.udp) ...[
                              const SizedBox(width: 4),
                              const _MiniTag('UDP'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isTesting)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    _MiniDelay(delay, onTap: onTest),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: s.textPrimary,
                            fontSize: 11.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            size: 11, color: cs.primary),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (isTesting)
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  else
                    Text(
                      delay == null
                          ? '—'
                          : delay! < 0
                              ? '超时'
                              : '${delay}ms',
                      style: TextStyle(
                        color: delayColor(delay, cs),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : s.textTertiary.withValues(alpha: 0.5),
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _labels = {
    'default': '默认（规则/区域）',
    'nameAsc': '名称 A→Z',
    'nameDesc': '名称 Z→A',
    'delayAsc': '延时 低→高',
    'delayDesc': '延时 高→低',
  };

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: s.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card)),
      itemBuilder: (_) => _labels.entries
          .map((e) => PopupMenuItem<String>(
                value: e.key,
                child: Row(
                  children: [
                    Icon(
                      value == e.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: value == e.key
                          ? Theme.of(context).colorScheme.primary
                          : s.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Text(e.value,
                        style: TextStyle(color: s.textPrimary, fontSize: 13)),
                  ],
                ),
              ))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(Icons.sort_rounded, size: 19, color: s.textSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------- 供应商

class _ProvidersView extends ConsumerWidget {
  const _ProvidersView({required this.onPickNode});

  final void Function(String groupName) onPickNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final async = ref.watch(providersProvider);
    // 分组型的 provider（vehicleType=Compatible）不是真实机场，过滤掉
    final providers = (async.value ?? const {})
        .entries
        .where((e) => e.value.vehicleType.toLowerCase() != 'compatible')
        .fold<Map<String, ProviderInfo>>({}, (m, e) => m..[e.key] = e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Text('${providers.length} 个机场订阅',
              style: TextStyle(color: s.textTertiary, fontSize: 11.5)),
        ),
        Expanded(
          child: providers.isEmpty
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: async.isLoading ? '读取中…' : '没有供应商',
                  subtitle: '订阅型代理提供者会显示在这里',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: providers.length,
                  itemBuilder: (context, i) {
                    final p = providers.values.elementAt(i);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: JellyEntry(
                        index: i,
                        staggerMs: 22,
                        child: _ProviderCard(provider: p),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProviderCard extends ConsumerStatefulWidget {
  const _ProviderCard({required this.provider});

  final ProviderInfo provider;

  @override
  ConsumerState<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends ConsumerState<_ProviderCard> {
  final GlobalKey _key = GlobalKey();

  void _open(BuildContext context) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final rect = box == null || !box.hasSize
        ? Rect.fromLTWH(16, 300, 320, 120)
        : (box.localToGlobal(Offset.zero) & box.size);
    final st = ref.read(settingsProvider);
    showExpandingSheet<void>(
      context: context,
      origin: rect,
      heightFactor: 0.52,
      panelOpacity:
          st.sheetGlass ? st.surfaceOpacity.clamp(0.5, 1.0) : 1.0,
      glass: st.sheetGlass,
      blur: st.sheetBlur,
      originRadius: 18,
      reverseDuration: const Duration(milliseconds: 180),
      builder: (_) => _ProviderNodesSheet(provider: widget.provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final days = provider.daysLeft;
    final expired = days != null && days < 0;
    final soon = days != null && days >= 0 && days <= 7;
    final count = provider.proxies.isNotEmpty
        ? provider.proxies.length
        : provider.nodes.length;

    // 可用节点统计：延时 > 0 视为可用
    final nodes = provider.proxies.isNotEmpty
        ? provider.proxies
        : provider.nodes.map((n) => MihomoProxy(name: n, type: '')).toList();
    final total = nodes.length;
    final avail = nodes.where((n) => (n.delay ?? 0) > 0).length;
    final delays = nodes
        .map((n) => n.delay ?? 0)
        .where((d) => d > 0)
        .toList()
      ..sort();
    final avgDelay =
        delays.isEmpty ? 0 : delays[delays.length ~/ 2];
    // 分段统计：<300ms 绿、300-699 黄、>=700 或超时 红
    var fastCount = 0;
    var midCount = 0;
    var slowCount = 0;
    var deadCount = 0;
    for (final n in nodes) {
      final d = n.delay ?? 0;
      if (d <= 0) {
        deadCount++;
      } else if (d < 300) {
        fastCount++;
      } else if (d < 700) {
        midCount++;
      } else {
        slowCount++;
      }
    }
    if (fastCount + midCount + slowCount + deadCount == 0) deadCount = 1;
    final availColor = avgDelay == 0
        ? AppColors.danger
        : (avgDelay < 300
            ? AppColors.success
            : (avgDelay < 700 ? AppColors.warning : AppColors.danger));

    return JellyPress(
      key: _key,
      onTap: () => _open(context),
      scaleTo: 0.94,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderLogo(provider: provider),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: s.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700)),
                      Text('$count 个节点 · ${provider.vehicleType}',
                          style: TextStyle(
                              color: s.textTertiary, fontSize: 10.5)),
                    ],
                  ),
                ),
                if (days != null)
                  StatusChip(
                    label: expired
                        ? '已过期'
                        : soon
                            ? '$days 天到期'
                            : '$days 天',
                    tone: expired || soon ? ChipTone.warn : ChipTone.ok,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('已用 ${fmtBytes(provider.used)}',
                    style: TextStyle(
                        color: provider.ratio > 0.9
                            ? AppColors.danger
                            : (provider.ratio > 0.75
                                ? AppColors.warning
                                : s.textSecondary),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  provider.total > 0 ? fmtBytes(provider.total) : '不限量',
                  style: TextStyle(color: s.textTertiary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: LinearProgressIndicator(
                value: provider.ratio,
                minHeight: 6,
                backgroundColor: s.block,
                valueColor: AlwaysStoppedAnimation(
                  provider.ratio > 0.9 ? AppColors.danger : cs.primary,
                ),
              ),
            ),
            if (provider.total > 0) ...[
              const SizedBox(height: 6),
              Text('剩余 ${fmtBytes(provider.remain)}',
                  style: TextStyle(color: s.textTertiary, fontSize: 10.5)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text('可用 $avail/$total',
                    style: TextStyle(
                        color: availColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (total > 0)
                  Text(
                    '共 $total 个',
                    style: TextStyle(color: s.textTertiary, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                height: 6,
                color: s.block,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fastCount > 0)
                      Expanded(
                        flex: fastCount,
                        child: const ColoredBox(color: AppColors.success),
                      ),
                    if (midCount > 0)
                      Expanded(
                        flex: midCount,
                        child: const ColoredBox(color: AppColors.warning),
                      ),
                    if (slowCount > 0)
                      Expanded(
                        flex: slowCount,
                        child: const ColoredBox(color: AppColors.danger),
                      ),
                    if (deadCount > 0)
                      Expanded(
                        flex: deadCount,
                        child: ColoredBox(
                          color: s.textTertiary.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 供应商节点：悬浮窗 + 网格（跟随列数设置）
class _ProviderNodesSheet extends ConsumerStatefulWidget {
  const _ProviderNodesSheet({required this.provider});

  final ProviderInfo provider;

  @override
  ConsumerState<_ProviderNodesSheet> createState() =>
      _ProviderNodesSheetState();
}

class _ProviderNodesSheetState extends ConsumerState<_ProviderNodesSheet> {
  Map<String, MihomoProxy> get _proxies =>
      ref.read(proxiesProvider).value ?? const {};
  final Map<String, int?> _delays = {};
  bool _testing = false;

  List<MihomoProxy> get _nodes => widget.provider.proxies;

  Future<void> _testAll() async {
    if (_testing || _nodes.isEmpty) return;
    setState(() => _testing = true);
    final demo = ref.read(settingsProvider).demoMode;
    final client = ref.read(clientProvider);
    if (demo) {
      for (final n in _nodes) {
        _delays[n.name] = 40 + (n.name.hashCode.abs() % 260);
      }
      if (mounted) setState(() => _testing = false);
      return;
    }
    final result =
        await client?.testProviderAll(widget.provider.name) ?? const {};
    if (mounted) {
      setState(() {
        _delays.addAll(result);
        _testing = false;
      });
    }
  }

  Future<void> _testOne(MihomoProxy n) async {
    final demo = ref.read(settingsProvider).demoMode;
    if (demo) {
      setState(() => _delays[n.name] = 40 + (n.name.hashCode.abs() % 260));
      return;
    }
    setState(() => _delays[n.name] = null);
    final d = await ref
        .read(clientProvider)
        ?.testProviderNode(widget.provider.name, n.name);
    if (mounted) {
      setState(() => _delays[n.name] = d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final nodes = _nodes;
    final cols = ref.watch(settingsProvider).proxyColumns;

    Widget tile(int i) {
      final n = nodes[i];
      final delay = effectiveDelay(n, _proxies, _delays);
      final st = ref.watch(settingsProvider);
      return Padding(
        padding: EdgeInsets.only(bottom: st.nodeGap),
        child: JellyPress(
          haptic: false,
          onTap: () => _testOne(n),
          scaleTo: 0.98,
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: 10, vertical: st.nodePadV),
            decoration: BoxDecoration(
              color: s.inset,
              borderRadius: BorderRadius.circular(
                  ref.watch(settingsProvider).nodeRadius),
              border: Border.all(
                  color: s.hairline.withValues(alpha: 0.22),
                  width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: s.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        nodeSubtitle(n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: s.textTertiary,
                            fontSize: 9.5,
                            height: 1.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                delay == null
                    ? JellyPress(
                        haptic: false,
                        onTap: () => _testOne(n),
                        child: Icon(Icons.timer_outlined,
                            size: 14, color: s.textTertiary),
                      )
                    : _MiniDelay(delay),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.provider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: s.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text('${nodes.length} 个节点 · 点节点测速',
                          style:
                              TextStyle(color: s.textTertiary, fontSize: 10.5)),
                    ],
                  ),
                ),
                JellyPress(
                  haptic: false,
                  onTap: _testAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: _testing
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speed_rounded,
                                  size: 13, color: s.textSecondary),
                              const SizedBox(width: 3),
                              Text('全部测速',
                                  style: TextStyle(
                                      color: s.textSecondary, fontSize: 11)),
                            ],
                          ),
                  ),
                ),
                JellyPress(
                  haptic: false,
                  onTap: () => Navigator.of(context).pop(),
                  scaleTo: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: s.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: nodes.isEmpty
                ? const EmptyState(
                    icon: Icons.dns_outlined,
                    title: '这个供应商没有返回节点',
                    subtitle: '内核只给了名字、没给节点对象',
                  )
                : cols == 1
                    ? ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                        itemCount: nodes.length,
                        itemBuilder: (context, i) => tile(i),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: cols == 2 ? 2.6 : 1.9,
                        ),
                        itemCount: nodes.length,
                        itemBuilder: (context, i) => tile(i),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider});

  final ProviderInfo provider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = provider.icon;
    if (icon == null) {
      return CookieBadge(
        icon: Icons.cloud_rounded,
        size: 34,
        color: cs.primary.withValues(alpha: 0.12),
      );
    }
    return CachedLogo(
      url: icon,
      size: 34,
      radius: 10,
      fallback: CookieBadge(
        icon: Icons.cloud_rounded,
        size: 34,
        color: cs.primary.withValues(alpha: 0.12),
      ),
    );
  }
}

String _groupTypeLabel(String type) => type.toUpperCase();

/// 自动选择型分组（url-test / fallback）
bool _isAutoType(String type) {
  final t = type.toLowerCase();
  return t == 'url-test' ||
      t == 'urltest' ||
      t == 'fallback' ||
      t == 'load-balance' ||
      t == 'loadbalance';
}


/// 分组显示用的延时：跟随它当前选中的节点（可递归套娃）
int? effectiveDelay(
  MihomoProxy node,
  Map<String, MihomoProxy> proxies,
  Map<String, int?> overrides, [
  int depth = 0,
]) {
  if (!node.isGroup) {
    return overrides[node.name] ?? node.delay;
  }
  if (depth > 5) return null;
  final now = node.now;
  if (now == null) return null;
  final next = proxies[now];
  if (next == null) return overrides[now];
  return effectiveDelay(next, proxies, overrides, depth + 1);
}

/// 只统计当前分组的直接成员：节点各算 1 个，套娃分组也各算 1 个
({int available, int total}) groupStats(
  MihomoProxy group,
  Map<String, MihomoProxy> proxies,
  Map<String, int?> overrides,
) {
  var total = 0;
  var available = 0;
  for (final name in group.all) {
    total += 1;
    final p = proxies[name];
    if (p == null) continue;
    if (p.isGroup) {
      // 套娃分组按它当前选中的节点是否可用来判断
      final now = p.now;
      final d = now == null ? null : (overrides[now] ?? proxies[now]?.delay);
      if (d != null && d > 0) available += 1;
    } else {
      final d = overrides[name] ?? p.delay;
      if (d != null && d > 0) available += 1;
    }
  }
  return (available: available, total: total);
}



/// 协议缩写：hysteria2 → hy2，shadowsocks → ss
String shortProtocol(String type) => switch (type.toLowerCase()) {
      'hysteria2' => 'hy2',
      'hysteria' => 'hy',
      'shadowsocks' => 'ss',
      'shadowsocksr' => 'ssr',
      'socks5' => 'socks',
      _ => type.toLowerCase(),
    };

/// 节点副标题：协议小写 + udp/xudp
String nodeSubtitle(MihomoProxy n) {
  final proto = shortProtocol(n.type);
  final transport = n.xudp ? 'xudp' : (n.udp ? 'udp' : '');
  return transport.isEmpty ? proto : '$proto / $transport';
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: s.inset,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: s.textTertiary,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 分组里有节点名、但代理表里找不到对应条目时，把线索直接列出来
class _NodeMismatch extends StatelessWidget {
  const _NodeMismatch({
    required this.groupName,
    required this.groupNodeNames,
    required this.proxyKeys,
  });

  final String groupName;
  final List<String> groupNodeNames;
  final List<String> proxyKeys;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final missing =
        groupNodeNames.where((n) => !proxyKeys.contains(n)).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 15, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text('节点数据对不上',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '分组「$groupName」列出了 ${groupNodeNames.length} 个节点，'
                '但代理表里只有 ${proxyKeys.length} 个条目。',
                style: TextStyle(
                    color: s.textSecondary, fontSize: 11, height: 1.4),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('对不上的名字（前 3 个）：',
                    style: TextStyle(color: s.textTertiary, fontSize: 10)),
                Text(missing.map((e) => '「$e」').join('  '),
                    style: TextStyle(color: s.textPrimary, fontSize: 10.5)),
              ],
              const SizedBox(height: 6),
              Text('代理表里的键（前 6 个）：',
                  style: TextStyle(color: s.textTertiary, fontSize: 10)),
              Text(proxyKeys.take(6).map((e) => '「$e」').join('  '),
                  style: TextStyle(color: s.textPrimary, fontSize: 10.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 分组节点悬浮窗：显示节点、可测速、可切换
class _GroupNodesSheet extends ConsumerStatefulWidget {
  const _GroupNodesSheet({required this.groupName});

  final String groupName;

  @override
  ConsumerState<_GroupNodesSheet> createState() => _GroupNodesSheetState();
}

class _GroupNodesSheetState extends ConsumerState<_GroupNodesSheet> {
  final Map<String, int?> _delays = {};
  final Set<String> _busy = {};
  Map<String, MihomoProxy> get _proxies =>
      ref.read(proxiesProvider).value ?? const {};
  bool _testing = false;

  List<MihomoProxy> _nodes(Map<String, MihomoProxy> proxies) {
    final group = proxies[widget.groupName];
    if (group == null) return const [];
    return group.all.map((n) {
      // 有些子分组/节点不在代理表里，用占位对象保证能显示
      return proxies[n] ??
          MihomoProxy(name: n, type: 'Selector', groupHint: true);
    }).toList();
  }

  Future<void> _testAll(List<MihomoProxy> nodes) async {
    if (_testing) return;
    ref.read(manualGroupsProvider.notifier).clear(widget.groupName);
    setState(() => _testing = true);
    final client = ref.read(clientProvider);
    final settings = ref.read(settingsProvider);
    // 「交给内核」时用机场配置的测速地址；没有就用默认地址兜底
    String url = settings.delayTestUrl;
    if (settings.delayTestMode != 'app') {
      final provs = ref.read(providersProvider).value ?? const {};
      final configured = provs.values
          .map((p) => p.testUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
      if (configured.isNotEmpty) url = configured.first;
    }
    try {
    // 逐节点并发测：测得一个就在界面上填一个（zashboard 的做法）
    final provs = ref.read(providersProvider).value ?? const {};
    final providerOf = <String, String>{};
    for (final e in provs.entries) {
      for (final p in e.value.proxies) {
        providerOf[p.name] = e.key;
      }
    }

    final results = <String, int>{};
    const concurrency = 6;
    var index = 0;

    Future<void> worker() async {
      while (index < nodes.length) {
        final n = nodes[index++];
        int? d;
        final prov = providerOf[n.name];
        if (prov != null) {
          d = await client?.testProviderNode(prov, n.name);
        } else {
          d = await client?.testDelay(n.name, url: url);
        }
        results[n.name] = d ?? -1;
        if (mounted) setState(() => _delays[n.name] = d ?? -1);
      }
    }

    await Future.wait(List.generate(
      nodes.length < concurrency ? nodes.length : concurrency,
      (_) => worker(),
    ));

    if (mounted) {
      setState(() => _testing = false);
    }
    } catch (_) {
      if (mounted) setState(() => _testing = false);
    } finally {
      if (mounted && _testing) {
        setState(() => _testing = false);
      }
    }
  }

  /// 只测这一个节点（有 provider 走 healthcheck，否则走 /proxies/{name}/delay）
  Future<void> _testNode(MihomoProxy node) async {
    final client = ref.read(clientProvider);
    if (client == null) return;
    if (node.isGroup) {
      // 子分组本身没有延时，测它当前选中的节点
      final now = node.now;
      if (now != null) {
        final proxiesNow = ref.read(proxiesProvider).value ?? const {};
        final leaf = proxiesNow[now];
        final target =
            leaf == null ? const <MihomoProxy>[] : <MihomoProxy>[leaf];
        if (target.isNotEmpty) return _testNode(target.first);
      }
      return;
    }
    setState(() => _busy.add(node.name));

    final settings = ref.read(settingsProvider);
    var url = settings.delayTestUrl;
    if (settings.delayTestMode != 'app') {
      final configured = (ref.read(providersProvider).value ?? const {})
          .values
          .map((p) => p.testUrl)
          .whereType<String>()
          .where((u) => u.isNotEmpty)
          .toList();
      if (configured.isNotEmpty) url = configured.first;
    }

    String? prov;
    for (final e in (ref.read(providersProvider).value ?? const {}).entries) {
      if (e.value.proxies.any((p) => p.name == node.name)) {
        prov = e.key;
        break;
      }
    }

    int? d;
    try {
      d = prov != null
          ? await client.testProviderNode(prov, node.name)
          : await client.testDelay(node.name, url: url);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _busy.remove(node.name);
        _delays[node.name] = d ?? -1;
      });
    }
  }

  Future<void> _select(MihomoProxy node) async {
    try {
      final group = (ref.read(proxiesProvider).value ?? const {})[
          widget.groupName];
      if (group != null && _isAutoType(group.type)) {
        ref.read(manualGroupsProvider.notifier).mark(widget.groupName);
      }
      await ref
          .read(clientProvider)
          ?.selectProxy(widget.groupName, node.name);
      // 立即反映到界面，避免等下一轮轮询
      ref.read(nowOverrideProvider.notifier).set(widget.groupName, node.name);
      // 清掉该节点旧的测速结果，让延时回到内核最新值
      ref.read(delayOverridesProvider.notifier).remove(node.name);
    } catch (_) {}
    ref.invalidate(proxiesProvider);
  }

  /// 子分组永远排最前，其余按设置排序
  List<MihomoProxy> _applyNodeSort(
    List<MihomoProxy> list,
    String mode,
    Map<String, int?> delays,
  ) {
    final subgroups = list.where((n) => n.isGroup).toList();
    final leaves = list.where((n) => !n.isGroup).toList();
    int delayOf(MihomoProxy n) =>
        delays[n.name] ?? n.delay ?? (1 << 30);

    switch (mode) {
      case 'config':
        break;
      case 'nameAsc':
        leaves.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'nameDesc':
        leaves.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'delayAsc':
        leaves.sort((a, b) => delayOf(a).compareTo(delayOf(b)));
      case 'delayDesc':
        leaves.sort((a, b) => delayOf(b).compareTo(delayOf(a)));
      default:
        sortByRank(leaves, (n) => nodeRank(n.name));
    }
    return [...sortByRank(subgroups, (n) => 0), ...leaves];
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final proxies = ref.watch(proxiesProvider).value ?? const {};
    final group = proxies[widget.groupName];
    final nodes = _nodes(proxies);
    final settings = ref.watch(settingsProvider);
    final filtered = settings.hideTimeout
        ? nodes.where((n) {
            if (n.isGroup) return true;
            final d = _delays.containsKey(n.name) ? _delays[n.name] : n.delay;
            return d == null || d > 0;
          }).toList()
        : nodes;
    final sorted = _applyNodeSort(filtered, settings.nodeSortMode, _delays);

    final now =
        ref.watch(nowOverrideProvider)[widget.groupName] ?? group?.now;
    final nowNode = now == null ? null : proxies[now];
    final nowDelay = now == null
        ? null
        : (_delays[now] ?? nowNode?.delay);
    final stats = group == null
        ? (available: 0, total: nodes.length)
        : groupStats(group, proxies, _delays);

    Widget tile(int i) {
      final n = sorted[i];
      final delay = effectiveDelay(n, _proxies, _delays);
      final selected = now == n.name;
      final st = ref.watch(settingsProvider);
      return Padding(
        padding: EdgeInsets.only(bottom: st.nodeGap),
        child: JellyPress(
          haptic: false,
          onTap: () => _select(n),
          scaleTo: 0.98,
          child: Container(
            padding: EdgeInsets.fromLTRB(11, st.nodePadV, 11, st.nodePadV),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.24)
                  : s.inset,
              borderRadius: BorderRadius.circular(
                  ref.watch(settingsProvider).nodeRadius),
              border: selected
                  ? null
                  : Border.all(
                      color: s.hairline.withValues(alpha: 0.22),
                      width: 0.5,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (n.isGroup) ...[
                      _GroupLogo(proxy: n, size: 14),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        n.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: s.textPrimary,
                          fontSize: st.nodeFontSize,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nodeSubtitle(n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: s.textTertiary,
                            fontSize: 9.5,
                            height: 1.1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    (_testing && !_delays.containsKey(n.name)) ||
                            _busy.contains(n.name)
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : delay == null
                            ? JellyPress(
                                haptic: false,
                                onTap: () => _testNode(n),
                                child: Icon(Icons.timer_outlined,
                                    size: 14, color: s.textTertiary),
                              )
                            : _MiniDelay(delay,
                                onTap: () => _testNode(n), size: 11),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: s.textPrimary,
                            fontSize:
                                18 * ref.watch(settingsProvider).titleScale,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (group != null)
                      _GroupLogo(proxy: group, size: 34),
                  ],
                ),
                Text(
                  '${_groupTypeLabel(group?.type ?? '')}'
                  '${stats.total > 0 ? ' · ${stats.available}/${stats.total}' : ''}',
                  style: TextStyle(color: s.textTertiary, fontSize: 10),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded,
                        size: 13, color: s.textTertiary),
                    const SizedBox(width: 4),
                    if (now != null)
                      _GroupLogo(
                          proxy: nowNode ?? MihomoProxy(name: now, type: ''),
                          size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        now ?? '未选择',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: s.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MiniDelay(nowDelay, onTap: () => _testAll(nodes), size: 11),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Builder(
              builder: (context) {
                final cols = settings.proxyColumns;

                // 按机场分组显示
                if (settings.groupByProvider) {
                  final providerOf = <String, String>{};
                  final provs = ref.watch(providersProvider).value ?? const {};
                  for (final e in provs.entries) {
                    for (final p in e.value.proxies) {
                      providerOf[p.name] = e.key;
                    }
                  }
                  final buckets = <String, List<MihomoProxy>>{};
                  for (final n in sorted) {
                    final key = n.isGroup
                        ? '节点组'
                        : (providerOf[n.name] ?? '未分组');
                    buckets.putIfAbsent(key, () => []).add(n);
                  }
                  final entries = buckets.entries.toList()
                    ..sort((a, b) => a.key == '节点组'
                        ? -1
                        : (b.key == '节点组' ? 1 : a.key.compareTo(b.key)));
                  final cols2 = cols;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                    children: [
                      for (final e in entries) ...[
                        if (e.key != '节点组')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                            child: Row(
                              children: [
                                Text(e.key,
                                    style: TextStyle(
                                        color: s.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Text('${e.value.length}',
                                    style: TextStyle(
                                        color: s.textTertiary, fontSize: 10)),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 2),
                        if (cols2 == 1)
                          for (final n in e.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: tile(sorted.indexOf(n)),
                            )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols2,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: cols2 == 2 ? 2.9 : 2.1,
                            ),
                            itemCount: e.value.length,
                            itemBuilder: (context, i) =>
                                tile(sorted.indexOf(e.value[i])),
                          ),
                      ],
                    ],
                  );
                }

                if (cols == 1) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) => tile(i),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: cols == 2 ? 2.9 : 2.1,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) => tile(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 推断节点的 IP 族：内核有时不给，退化为按名字/类型判断
String ipFamilyOf(MihomoProxy p) {
  final v = p.ipVersion?.toLowerCase();
  if (v != null) {
    if (v.contains('6')) return 'IPv6';
    if (v.contains('4')) return 'IPv4';
  }
  final name = p.name.toLowerCase();
  if (name.contains('ipv6') || name.contains('v6')) return 'IPv6';
  return 'IPv4';
}


/// 右上角的小延时角标
class _MiniDelay extends StatelessWidget {
  const _MiniDelay(this.value, {this.onTap, this.size = 9});

  final int? value;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = delayColor(value, cs);
    final text = value == null
        ? '—'
        : value! < 0
            ? '超时'
            : '${value}ms';
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (onTap == null) return badge;
    return JellyPress(haptic: false, onTap: onTap, scaleTo: 0.9, child: badge);
  }
}

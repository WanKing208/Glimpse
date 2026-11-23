import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/jelly.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../widgets/common.dart';
import '../widgets/prism.dart';

class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key});

  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  List<String> get _tabLabels => [tr('规则'), tr('规则集')];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final rules = ref.watch(rulesProvider);
    final settings = ref.watch(settingsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ConnectionErrorBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Text(tr(tr('规则')),
                    style: TextStyle(
                        color: s.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9)),
                const Spacer(),
                Text(
                  settings.demoMode
                      ? '演示'
                      : (_idx == 0
                          ? '${rules.value?.length ?? 0} 条'
                          : '规则集'),
                  style: TextStyle(color: s.textTertiary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                JellyPress(
                  haptic: false,
                  onTap: () => setState(() => _idx = (_idx + 1) % 2),
                  scaleTo: 0.95,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          switch (_idx) {
                            0 => Icons.rule_rounded,
                            1 => Icons.folder_open_rounded,
                            _ => Icons.insights_rounded,
                          },
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _tabLabels[_idx],
                          style: TextStyle(
                            color: s.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.swap_horiz_rounded,
                            size: 13, color: s.textTertiary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 16, color: s.textTertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            style: TextStyle(
                                color: s.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '搜索规则',
                              hintStyle: TextStyle(
                                  color: s.textTertiary, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_idx) {
              0 => _RulesList(rules: rules, query: _query),
              _ => const _RuleProviders(),
            },
          ),
        ],
      ),
    );
  }
}

String ruleKey(RuleEntry r) => '${r.type}|${r.payload}|${r.proxy}';

class _RulesList extends ConsumerWidget {
  const _RulesList({required this.rules, required this.query});

  final AsyncValue<List<RuleEntry>> rules;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final overrides = ref.watch(ruleOverridesProvider);
    return rules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: '规则读取失败',
        subtitle: '$e',
      ),
      data: (list) {
        final q = query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? list
            : list
                .where((r) =>
                    r.payload.toLowerCase().contains(q) ||
                    r.proxy.toLowerCase().contains(q) ||
                    r.type.toLowerCase().contains(q))
                .toList();
        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.rule_rounded,
            title: '没有匹配的规则',
          );
        }
        return Column(
          children: [

            Expanded(
              child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final r = filtered[i];
            final disabled = overrides[r.index] ?? r.disabled;
            final traffic = ref.watch(ruleTrafficProvider)['${r.type} · ${r.payload}'];
            return JellyEntry(
              index: i.clamp(0, 10),
              staggerMs: 14,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: disabled ? 0.5 : 1,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(13, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: s.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: cardShadow(context),
                    ),
                    child: Row(
                      children: [
                        // 规则目标（代理组）的 logo，取配置里的 icon
                        _RuleLogo(proxyName: r.proxy),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${r.index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: s.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.inset,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(r.type,
                              style: TextStyle(
                                  color: s.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.payload.isEmpty ? '（兜底）' : r.payload,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: s.textPrimary,
                                fontSize: 13,
                                decoration: disabled
                                    ? TextDecoration.lineThrough
                                    : null),
                          ),
                        ),
                        if (traffic != null && traffic > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '↑↓${fmtBytes(traffic)}',
                            style: TextStyle(
                              color: s.textTertiary,
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          r.proxy,
                          style: TextStyle(
                            color: _proxyColor(r.proxy),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.78,
                          child: Switch.adaptive(
                            value: !disabled,
                            onChanged: (on) => _toggleRule(ref, r, on),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleRule(WidgetRef ref, RuleEntry r, bool on) async {
    final disabled = !on;
    final overrides = ref.read(ruleOverridesProvider.notifier);
    overrides.set(r.index, disabled);
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) return;
    final client = ref.read(clientProvider);
    try {
      await client?.setRulesDisabled({r.index: disabled});
      if (!disabled) await client?.refindRule(r.uuid);
    } catch (_) {
      // 失败回滚
      overrides.set(r.index, r.disabled);
    }
  }

  Color _proxyColor(String proxy) {
    if (proxy == 'DIRECT') return const Color(0xFF30A46C);
    if (proxy == 'REJECT') return const Color(0xFFE5484D);
    return const Color(0xFF4F7CFF);
  }
}

/// 规则集供应商列表
class _RuleProviders extends ConsumerWidget {
  const _RuleProviders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final async = ref.watch(ruleProvidersProvider);
    final providers = async.value ?? const {};

    if (providers.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_rounded,
        title: async.isLoading ? '读取中…' : '没有规则集',
        subtitle: '在配置里使用 rule-providers 后会显示在这里',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: providers.length,
      itemBuilder: (context, i) {
        final p = providers.values.elementAt(i);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: JellyEntry(
            index: i,
            staggerMs: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: s.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: cardShadow(context),
              ),
              child: Row(
                children: [
                  CookieBadge(
                    icon: Icons.folder_rounded,
                    size: 34,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: s.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.inset,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(p.behavior,
                                  style: TextStyle(
                                      color: s.textTertiary, fontSize: 9.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${p.ruleCount} 条规则'
                          '${p.updatedAt == null ? '' : ' · ${fmtAgo(p.updatedAt!)}更新'}',
                          style: TextStyle(
                              color: s.textTertiary, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  JellyPress(
                    haptic: false,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final settings = ref.read(settingsProvider);
                      if (settings.demoMode) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('演示模式：已模拟更新')),
                        );
                        return;
                      }
                      try {
                        await ref
                            .read(clientProvider)
                            ?.updateRuleProvider(p.name);
                        ref.invalidate(ruleProvidersProvider);
                        messenger.showSnackBar(
                          SnackBar(content: Text('${p.name} 已更新')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('更新失败：$e')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: s.block,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text('更新',
                          style: TextStyle(
                              color: s.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 规则目标（代理组）的 logo：优先取配置文件里的 icon
class _RuleLogo extends ConsumerWidget {
  const _RuleLogo({required this.proxyName});

  final String proxyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final proxies = ref.watch(proxiesProvider).value ?? const {};
    final proxy = proxies[proxyName];
    const size = 26.0;

    if (proxy == null) {
      // 直连 / 拒绝 / 未加载时用图标占位
      final up = proxyName.toUpperCase();
      final isDirect = up == 'DIRECT';
      final isReject = up == 'REJECT';
      return CookieBadge(
        icon: isDirect
            ? Icons.check_circle_outline_rounded
            : isReject
                ? Icons.block_rounded
                : Icons.swap_horiz_rounded,
        size: size,
        color: (isDirect
                ? const Color(0xFF30A46C)
                : isReject
                    ? const Color(0xFFE5484D)
                    : cs.primary)
            .withValues(alpha: 0.14),
      );
    }

    return ProxyLogo(proxy: proxy, size: size);
  }
}

import 'dart:convert';
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

/// 连接可选字段（对齐 zashboard 的 CONNECTIONS_TABLE_ACCESSOR_KEY）
enum ConnField {
  type('type', '类型'),
  process('process', '进程'),
  host('host', '域名'),
  rule('rule', '规则'),
  chains('chains', '链路'),
  outbound('outbound', '出口'),
  dlSpeed('dlSpeed', '下行速度'),
  ulSpeed('ulSpeed', '上行速度'),
  dl('dl', '下行总量'),
  ul('ul', '上行总量'),
  connectTime('connectTime', '连接时长'),
  sourceIP('sourceIP', '来源 IP'),
  sourcePort('sourcePort', '来源端口'),
  sniffHost('sniffHost', '嗅探域名'),
  destination('destination', '目的地'),
  destinationType('destinationType', '目标类型'),
  network('network', '网络'),
  rulePayload('rulePayload', '规则内容'),
  processPath('processPath', '进程路径');

  const ConnField(this.id, this.label);
  final String id;
  final String label;
}

const kDefaultConnFields = <String>[
  'host',
  'chains',
  'dl',
  'ul',
  'connectTime',
];

/// 分组维度（对齐 zashboard 的 CONNECTION_GROUPABLE_KEYS）
enum ConnGroup {
  none('none', '不分组'),
  host('host', '按域名'),
  process('process', '按进程'),
  rule('rule', '按规则'),
  chains('chains', '按链路'),
  outbound('outbound', '按出口'),
  type('type', '按类型'),
  time('time', '按时间');

  const ConnGroup(this.id, this.label);
  final String id;
  final String label;
}

class ConnFieldsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final raw = prefs.getString('glimpse.conn.fields');
    if (raw == null || raw.isEmpty) return kDefaultConnFields;
    final list = raw.split(',').where((e) => e.isNotEmpty).toList();
    return list.isEmpty ? kDefaultConnFields : list;
  }

  void toggle(String id) {
    final list = [...state];
    list.contains(id) ? list.remove(id) : list.add(id);
    state = list;
    prefs.setString('glimpse.conn.fields', list.join(','));
  }

  void reset() {
    state = kDefaultConnFields;
    prefs.setString('glimpse.conn.fields', kDefaultConnFields.join(','));
  }
}

final connFieldsProvider =
    NotifierProvider<ConnFieldsNotifier, List<String>>(ConnFieldsNotifier.new);

class ConnGroupNotifier extends Notifier<ConnGroup> {
  @override
  ConnGroup build() {
    final raw = prefs.getString('glimpse.conn.group') ?? 'none';
    return ConnGroup.values.firstWhere(
      (g) => g.id == raw,
      orElse: () => ConnGroup.none,
    );
  }

  void set(ConnGroup g) {
    state = g;
    prefs.setString('glimpse.conn.group', g.id);
  }
}

final connGroupProvider =
    NotifierProvider<ConnGroupNotifier, ConnGroup>(ConnGroupNotifier.new);

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Map<String, int> _lastTotal = {};
  final Map<String, double> _speed = {};
  DateTime _lastTick = DateTime.now();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 用两次快照的差值估算实时速度
  void _updateSpeeds(List<ConnectionInfo> list) {
    final now = DateTime.now();
    final dt = now.difference(_lastTick).inMilliseconds / 1000.0;
    if (dt < 0.2) return;
    _lastTick = now;
    for (final c in list) {
      final prev = _lastTotal[c.id];
      final total = c.total;
      if (prev != null) {
        _speed[c.id] = ((total - prev) / dt).clamp(0, double.infinity);
      }
      _lastTotal[c.id] = total;
    }
    // 清理已断开的连接
    _lastTotal.removeWhere((id, _) => !list.any((c) => c.id == id));
    _speed.removeWhere((id, _) => !list.any((c) => c.id == id));
  }

  Future<void> _closeAll() async {
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) {
      ref.read(demoProvider).connections.clear();
      return;
    }
    try {
      await ref.read(clientProvider)?.closeAllConnections();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final all = ref.watch(connectionsProvider).value ?? const [];
    _updateSpeeds(all);

    final fields = ref.watch(connFieldsProvider);
    final group = ref.watch(connGroupProvider);

    final query = _query.trim().toLowerCase();
    final list = query.isEmpty
        ? all
        : all
            .where((c) =>
                c.host.toLowerCase().contains(query) ||
                c.chainText.toLowerCase().contains(query) ||
                c.destinationIP.contains(query) ||
                c.rulePayload.toLowerCase().contains(query) ||
                (c.processPath ?? '').toLowerCase().contains(query))
            .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(tr('连接')),
                          style: TextStyle(
                              color: s.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9)),
                      Text('活跃 ${all.length} 条',
                          style:
                              TextStyle(color: s.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                StatusChip(
                  label: group.label,
                  tone: group == ConnGroup.none
                      ? ChipTone.idle
                      : ChipTone.ok,
                  large: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _RoundBtn(
                  icon: Icons.account_tree_outlined,
                  tooltip: '分组',
                  onTap: () => _pickGroup(context, ref),
                ),
                const SizedBox(width: 8),
                _RoundBtn(
                  icon: Icons.view_column_outlined,
                  tooltip: '字段',
                  onTap: () => _pickFields(context, ref),
                ),
                const SizedBox(width: 8),
                Expanded(child: _searchField(s)),
                const SizedBox(width: 8),
                _RoundBtn(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: '全部断开',
                  danger: true,
                  onTap: _closeAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.link_off_rounded,
                    title: '没有活跃连接',
                    subtitle: '有流量通过时这里会实时刷新',
                  )
                : group == ConnGroup.none
                    ? _flatList(list, fields)
                    : _groupedList(list, fields, group),
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppSurfaces s) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: s.block,
        borderRadius: BorderRadius.circular(Radii.pill),
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
                hintText: '搜索',
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

  Widget _flatList(List<ConnectionInfo> list, List<String> fields) {
    final sorted = [...list]..sort((a, b) => b.start.compareTo(a.start));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: sorted.length,
      itemBuilder: (context, i) => JellyEntry(
        index: i.clamp(0, 10),
        staggerMs: 16,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ConnTile(
            conn: sorted[i],
            fields: fields,
            speed: _speed[sorted[i].id] ?? 0,
          ),
        ),
      ),
    );
  }

  Widget _groupedList(
      List<ConnectionInfo> list, List<String> fields, ConnGroup group) {
    final buckets = <String, List<ConnectionInfo>>{};
    for (final c in list) {
      final key = _groupKey(c, group);
      buckets.putIfAbsent(key, () => []).add(c);
    }
    final entries = buckets.entries.toList();
    if (group == ConnGroup.time) {
      entries.sort((a, b) => b.key.compareTo(a.key));
    } else {
      entries.sort((a, b) {
        final ta = a.value.fold<int>(0, (p, c) => p + c.total);
        final tb = b.value.fold<int>(0, (p, c) => p + c.total);
        return tb.compareTo(ta);
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final total = e.value.fold<int>(0, (p, c) => p + c.total);
        return JellyEntry(
          index: i.clamp(0, 10),
          staggerMs: 18,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlimpseCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => _showGroupSheet(context, e.key, e.value, fields),
              child: Row(
                children: [
                  CookieBadge(
                    icon: Icons.lan_outlined,
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
                        Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: surfacesOf(context).textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.value.length} 条连接',
                          style: TextStyle(
                              color: surfacesOf(context).textTertiary,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fmtBytes(total),
                    style: TextStyle(
                      color: surfacesOf(context).textSecondary,
                      fontSize: 11.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 17, color: surfacesOf(context).textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _groupKey(ConnectionInfo c, ConnGroup g) {
    return switch (g) {
      ConnGroup.host => c.host.isEmpty ? '未知域名' : c.host,
      ConnGroup.process =>
        (c.processPath ?? '').isEmpty ? '未知进程' : c.processPath!,
      ConnGroup.rule => c.rule.isEmpty ? '未知规则' : c.rule,
      ConnGroup.chains => c.chainText.isEmpty ? '直连' : c.chainText,
      ConnGroup.outbound =>
        c.chains.isEmpty ? 'DIRECT' : c.chains.first,
      ConnGroup.type => c.type.isEmpty ? '未知' : c.type,
      ConnGroup.time => () {
          final h = c.start.hour.toString().padLeft(2, '0');
          final m = c.start.minute.toString().padLeft(2, '0');
          return '$h:$m';
        }(),
      ConnGroup.none => '',
    };
  }

  void _showGroupSheet(BuildContext context, String key,
      List<ConnectionInfo> items, List<String> fields) {
    showJellySheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: surfacesOf(context).textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ),
                    Text('${items.length} 条',
                        style: TextStyle(
                            color: surfacesOf(context).textTertiary,
                            fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ConnTile(
                      conn: items[i],
                      fields: fields,
                      speed: _speed[items[i].id] ?? 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickGroup(BuildContext context, WidgetRef ref) {
    final current = ref.read(connGroupProvider);
    showJellySheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('分组方式',
                  style: TextStyle(
                      color: surfacesOf(context).textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
            for (final g in ConnGroup.values)
              ListTile(
                title: Text(g.label,
                    style: TextStyle(
                        color: surfacesOf(context).textPrimary,
                        fontSize: 14.5)),
                trailing: current == g
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  ref.read(connGroupProvider.notifier).set(g);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _pickFields(BuildContext context, WidgetRef ref) {
    showJellySheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, r, _) {
          final sel = r.watch(connFieldsProvider);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('显示字段',
                              style: TextStyle(
                                  color: surfacesOf(context).textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                        ),
                        JellyTextButton(
                          label: '恢复默认',
                          onPressed: () =>
                              r.read(connFieldsProvider.notifier).reset(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      children: [
                        for (final f in ConnField.values)
                          CheckboxListTile(
                            value: sel.contains(f.id),
                            onChanged: (_) =>
                                r.read(connFieldsProvider.notifier).toggle(f.id),
                            title: Text(f.label,
                                style: TextStyle(
                                    color: surfacesOf(context).textPrimary,
                                    fontSize: 14)),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final color = danger ? AppColors.danger : s.textSecondary;
    return Tooltip(
      message: tooltip ?? '',
      child: JellyPress(
        onTap: onTap,
        haptic: false,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: danger
                ? AppColors.danger.withValues(alpha: 0.10)
                : s.block,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ConnTile extends StatelessWidget {
  const _ConnTile({
    required this.conn,
    required this.fields,
    required this.speed,
  });

  final ConnectionInfo conn;
  final List<String> fields;
  final double speed;

  String? _value(ConnField f) {
    return switch (f) {
      ConnField.type => conn.type,
      ConnField.process =>
        (conn.processPath ?? '').isEmpty ? null : conn.processPath,
      ConnField.host => conn.host,
      ConnField.rule => conn.rule,
      ConnField.chains => conn.chainText,
      ConnField.outbound => conn.chains.isEmpty ? null : conn.chains.first,
      ConnField.dlSpeed => fmtSpeed(speed),
      ConnField.ulSpeed => null,
      ConnField.dl => fmtBytes(conn.download),
      ConnField.ul => fmtBytes(conn.upload),
      ConnField.connectTime =>
        fmtDuration(DateTime.now().difference(conn.start)),
      ConnField.sourceIP => conn.sourceIP,
      ConnField.sourcePort => conn.sourcePort,
      ConnField.sniffHost => conn.sniffHost,
      ConnField.destination =>
        '${conn.destinationIP}:${conn.destinationPort ?? ''}',
      ConnField.destinationType => conn.network.toUpperCase(),
      ConnField.network => conn.network,
      ConnField.rulePayload => conn.rulePayload,
      ConnField.processPath => conn.processPath,
    };
  }

  String _time(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final dur = DateTime.now().difference(conn.start);

    Widget line(String label, String? value, {bool strong = false}) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(label,
                  style: TextStyle(color: s.textTertiary, fontSize: 9.5)),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: strong ? s.textPrimary : s.textSecondary,
                  fontSize: strong ? 11.5 : 11,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return JellyPress(
      onTap: () => _showDetail(context),
      scaleTo: 0.98,
      child: GlimpseCard(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧：类型 / 域名 / 链路 / 规则
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line('类型', conn.type, strong: true),
                  line('域名', conn.host.isEmpty ? conn.destinationIP : conn.host),
                  line('链路', conn.chainText),
                  line('规则', conn.rulePayload.isEmpty
                      ? conn.rule
                      : '${conn.rule} · ${conn.rulePayload}'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 右侧：流量 / 时间 / 时长
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '↑${fmtBytes(conn.upload)}  ↓${fmtBytes(conn.download)}',
                  style: TextStyle(
                    color: s.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (fields.contains(ConnField.connectTime.id)) ...[
                  const SizedBox(height: 4),
                  Text(fmtDuration(dur),
                      style: TextStyle(
                          color: s.textTertiary,
                          fontSize: 10,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
                const Spacer(),
                Text(_time(conn.start),
                    style: TextStyle(
                        color: s.textTertiary,
                        fontSize: 10,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _raw() => {
        'id': conn.id,
        'host': conn.host,
        'destinationIP': conn.destinationIP,
        'destinationPort': conn.destinationPort,
        'sourceIP': conn.sourceIP,
        'sourcePort': conn.sourcePort,
        'network': conn.network,
        'type': conn.type,
        'rule': conn.rule,
        'rulePayload': conn.rulePayload,
        'chains': conn.chains,
        'processPath': conn.processPath,
        'sniffHost': conn.sniffHost,
        'upload': conn.upload,
        'download': conn.download,
        'start': conn.start.toIso8601String(),
      };

  void _showDetail(BuildContext context) {
    final s = surfacesOf(context);
    var showRaw = false;

    showJellyDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('连接详情',
                          style: TextStyle(
                              color: s.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded,
                          size: 20, color: s.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _DetailTab(
                      label: '字段',
                      active: !showRaw,
                      onTap: () => setState(() => showRaw = false),
                    ),
                    const SizedBox(width: 8),
                    _DetailTab(
                      label: '原始数据',
                      active: showRaw,
                      onTap: () => setState(() => showRaw = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: showRaw
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: s.inset,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(_raw()),
                              style: TextStyle(
                                color: s.textSecondary,
                                fontSize: 11,
                                height: 1.45,
                                fontFamily: 'monospace',
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final f in ConnField.values)
                                if ((_value(f)?.isNotEmpty ?? false))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 78,
                                          child: Text(f.label,
                                              style: TextStyle(
                                                  color: s.textTertiary,
                                                  fontSize: 12)),
                                        ),
                                        Expanded(
                                          child: Text(_value(f)!,
                                              style: TextStyle(
                                                  color: s.textPrimary,
                                                  fontSize: 12.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 详情弹窗顶部的小标签
class _DetailTab extends StatelessWidget {
  const _DetailTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    return JellyPress(
      haptic: false,
      onTap: onTap,
      scaleTo: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.16) : s.block,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? cs.primary : s.textSecondary,
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}


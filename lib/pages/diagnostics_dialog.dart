import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/jelly.dart';
import '../core/theme.dart';
import '../data/providers.dart';

/// 连接诊断：把各接口的真实结果打出来，便于排查"列表为空"
Future<void> showDiagnostics(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DiagnosticsDialog(),
  );
}

class _DiagnosticsDialog extends ConsumerStatefulWidget {
  const _DiagnosticsDialog();

  @override
  ConsumerState<_DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends ConsumerState<_DiagnosticsDialog> {
  final List<(String, String, bool)> _lines = [];
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _add(String label, String detail, [bool ok = true]) {
    if (!mounted) return;
    setState(() => _lines.add((label, detail, ok)));
  }

  Future<void> _run() async {
    setState(() {
      _lines.clear();
      _running = true;
    });

    final demo = ref.read(settingsProvider).demoMode;
    if (demo) {
      _add('当前模式', '演示模式，不会真实请求。请先关闭演示模式', false);
      setState(() => _running = false);
      return;
    }

    final client = ref.read(clientProvider);
    if (client == null) {
      _add('客户端', '地址为空，无法连接', false);
      setState(() => _running = false);
      return;
    }

    _add('控制器', client.baseUrl);
    _add('密钥', (client.secret ?? '').isEmpty ? '未设置' : '已设置',
        (client.secret ?? '').isNotEmpty);

    try {
      final v = await client.version();
      _add('/version', v);
    } catch (e) {
      _add('/version', describeError(e), false);
    }

    try {
      final p = await client.proxies();
      final groups = p.values.where((e) => e.isGroup).length;
      final nodes = p.length - groups;
      _add('/proxies', '共 ${p.length} 项（分组 $groups / 节点 $nodes）');
      if (p.isNotEmpty) {
        _add('样例键', p.keys.take(3).join(', '));
      }
      if (nodes == 0) {
        _add('提示', '没有解析到节点：可能所有条目都是分组，或节点名与分组 all 列表不匹配', false);
      }
    } catch (e) {
      _add('/proxies', describeError(e), false);
    }

    try {
      final pr = await client.providers();
      _add('/providers/proxies', '${pr.length} 个供应商',
          pr.isNotEmpty);
      if (pr.isEmpty) {
        _add('提示', '内核没有配置 proxy-providers，或该版本不支持此接口', false);
      }
    } catch (e) {
      _add('/providers/proxies', describeError(e), false);
    }

    try {
      final rp = await client.ruleProviders();
      _add('/providers/rules', '${rp.length} 个规则集', rp.isNotEmpty);
      if (rp.isEmpty) {
        _add('提示', '内核没有配置 rule-providers', false);
      }
    } catch (e) {
      _add('/providers/rules', describeError(e), false);
    }

    try {
      final rules = await client.rules();
      _add('/rules', '${rules.length} 条规则', rules.isNotEmpty);
    } catch (e) {
      _add('/rules', describeError(e), false);
    }

    try {
      final cfg = await client.configs();
      _add('/configs', '字段 ${cfg.length} 个');
      final mode = cfg['mode'];
      if (mode != null) _add('运行模式', '$mode');
    } catch (e) {
      _add('/configs', describeError(e), false);
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Dialog(
      backgroundColor: s.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('连接诊断',
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                JellyPress(
                  haptic: false,
                  enabled: !_running,
                  onTap: _running ? null : _run,
                  scaleTo: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.refresh_rounded,
                        size: 18, color: s.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_running)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (label, detail, ok) in _lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                ok
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.error_outline_rounded,
                                size: 13,
                                color: ok
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 110,
                                child: Text(label,
                                    style: TextStyle(
                                        color: s.textSecondary,
                                        fontSize: 11)),
                              ),
                              Expanded(
                                child: Text(
                                  detail,
                                  style: TextStyle(
                                      color: s.textPrimary, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: JellyTextButton(
                    label: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

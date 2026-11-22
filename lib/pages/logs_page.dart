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

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _scroll = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Color _levelColor(String type, BuildContext context) {
    return switch (type.toLowerCase()) {
      'error' => const Color(0xFFE5484D),
      'warning' || 'warn' => const Color(0xFFF76B15),
      'debug' => const Color(0xFF8E96A3),
      'info' => const Color(0xFF4F7CFF),
      _ => surfacesOf(context).textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final state = ref.watch(logsProvider);
    final level = ref.watch(logLevelProvider);

    final q = _query.trim().toLowerCase();
    final lines = q.isEmpty
        ? state.lines
        : state.lines.where((l) => l.payload.toLowerCase().contains(q)).toList();

    // 倒序，最新在上
    final view = lines.reversed.toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ConnectionErrorBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 2),
            child: Row(
              children: [
                Text(tr(tr('日志')),
                    style: TextStyle(
                        color: s.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9)),
                const Spacer(),
                Text('${lines.length}/500',
                    style: TextStyle(color: s.textTertiary, fontSize: 11.5)),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(
              children: [
                JellyPress(
                  haptic: false,
                  onTap: () {
                    const levels = ['info', 'warning', 'error', 'debug'];
                    final next = levels[(levels.indexOf(level) + 1) % levels.length];
                    ref.read(logLevelProvider.notifier).set(next);
                  },
                  scaleTo: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _levelColor(level, context),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          level,
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
                const SizedBox(width: 6),
                JellyPress(
                  haptic: false,
                  onTap: () => ref.read(logsProvider.notifier).togglePause(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: state.paused
                          ? const Color(0xFFF76B15).withValues(alpha: 0.16)
                          : s.block,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      state.paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 17,
                      color: state.paused
                          ? const Color(0xFFF76B15)
                          : s.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                JellyPress(
                  haptic: false,
                  onTap: () => ref.read(logsProvider.notifier).clear(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 17, color: s.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 15, color: s.textTertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            style: TextStyle(
                                color: s.textPrimary, fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '搜索',
                              hintStyle: TextStyle(
                                  color: s.textTertiary, fontSize: 12.5),
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
            child: view.isEmpty
                ? const EmptyState(
                    icon: Icons.terminal_rounded,
                    title: '暂无日志',
                    subtitle: '内核输出会实时出现在这里',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: view.length,
                    itemBuilder: (context, i) {
                      final line = view[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: s.card,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: cardShadow(context),
                          ),
                          child: _LogRow(
                            line: line,
                            color: _levelColor(line.type, context),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.line, required this.color});

  final LogLine line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              fmtClock(line.time),
              style: TextStyle(
                color: s.textTertiary,
                fontSize: 10.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 3,
            height: 13,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SelectableText(
              line.payload,
              style: TextStyle(
                color: s.textSecondary,
                fontSize: 11.5,
                height: 1.45,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

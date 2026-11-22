import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/geo.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'prism.dart';

/// 线路地图卡：在地图上画出本地 → 当前节点的连线，光点往复运动
class RouteMapCard extends ConsumerStatefulWidget {
  const RouteMapCard({super.key});

  @override
  ConsumerState<RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends ConsumerState<RouteMapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final proxies = ref.watch(proxiesProvider).value ?? const {};
    final nodeName = resolveExitName(proxies);
    final target = nodeName == null ? null : geoForName(nodeName);
    final here = ref.watch(localGeoProvider);

    return GlimpseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.route_rounded,
            title: '线路',
            trailing: [
              Text(
                target?.label ?? '未知地区',
                style: TextStyle(color: s.textTertiary, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/world_map.png',
                    fit: BoxFit.fill,
                    color: s.textPrimary.withValues(alpha: 0.16),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  if (here != null && target != null)
                    AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => CustomPaint(
                        painter: _RoutePainter(
                          from: here,
                          to: target,
                          t: _c.value,
                          accent: cs.primary,
                          dot: s.textPrimary,
                          faint: s.textTertiary,
                        ),
                      ),
                    ),
                  if (here == null || target == null)
                    Center(
                      child: Text(
                        here == null ? '等待获取本机位置…' : '无法识别节点地区',
                        style:
                            TextStyle(color: s.textTertiary, fontSize: 10.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Legend(color: cs.primary, text: here?.label ?? '本地'),
              const SizedBox(width: 14),
              _Legend(
                color: s.textPrimary.withValues(alpha: 0.7),
                text: target?.label ?? '—',
              ),
              const Spacer(),
              Text(
                nodeName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.textTertiary, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: s.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.from,
    required this.to,
    required this.t,
    required this.accent,
    required this.dot,
    required this.faint,
  });

  final GeoPoint from;
  final GeoPoint to;
  final double t;
  final Color accent;
  final Color dot;
  final Color faint;

  Offset _project(GeoPoint g, Size size) {
    final x = (g.lon + 180) / 360 * size.width;
    final y = (90 - g.lat) / 180 * size.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = _project(from, size);
    final b = _project(to, size);

    // 控制点：抬到两点连线中点上方，形成弧线
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final dist = (b - a).distance;
    final lift = math.min(size.height * 0.45, dist * 0.35 + 8);
    final ctrl = Offset(mid.dx, mid.dy - lift);

    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 端点
    canvas.drawCircle(a, 3, Paint()..color = accent);
    canvas.drawCircle(a, 6, Paint()..color = accent.withValues(alpha: 0.18));
    canvas.drawCircle(b, 3, Paint()..color = dot.withValues(alpha: 0.8));
    canvas.drawCircle(b, 6, Paint()..color = dot.withValues(alpha: 0.12));

    // 光点：去程 0-0.5，回程 0.5-1
    final local = t <= 0.5 ? t * 2 : 2 - t * 2;
    final p = _quad(a, ctrl, b, local);
    canvas.drawCircle(
        p, 7, Paint()..color = accent.withValues(alpha: 0.20));
    canvas.drawCircle(p, 3.2, Paint()..color = accent);

    // 标签
    void label(String text, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: faint, fontSize: 8.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (at.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      final dy = (at.dy - tp.height - 6).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(dx, dy));
    }

    label(from.label, a);
    label(to.label, b);
  }

  Offset _quad(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.t != t || old.from.lat != from.lat || old.to.lat != to.lat;
}



/// 顺着分组链找到真正的出口节点名（GLOBAL → 自建代理 → 节点）
String? resolveExitName(Map<String, MihomoProxy> proxies) {
  final groups = proxies.values.where((p) => p.isGroup).toList();
  if (groups.isEmpty) return null;
  groups.sort((a, b) => _rank(a.name).compareTo(_rank(b.name)));
  for (final g in groups) {
    final leaf = _leaf(proxies, g, 0);
    if (leaf != null) return leaf;
  }
  return null;
}

int _rank(String name) {
  final u = name.toUpperCase();
  if (u == 'GLOBAL') return 0;
  if (u.contains('PROXY')) return 1;
  if (u.contains('SELECT')) return 2;
  return 3;
}

String? _leaf(Map<String, MihomoProxy> proxies, MihomoProxy group, int depth) {
  if (depth > 6) return null;
  final now = group.now;
  if (now == null) return null;
  final next = proxies[now];
  if (next == null) return now;
  if (!next.isGroup) return now;
  return _leaf(proxies, next, depth + 1);
}

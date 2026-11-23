import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/jelly.dart';
import '../core/logo_cache.dart';
import '../data/providers.dart';
import '../core/theme.dart';

/// 圆角多边形路径（FlClash 的 cookie-6-sided 徽章形状）
Path roundedPolygonPath(Size size, int sides, double corner) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r = math.min(cx, cy);
  final pts = <Offset>[];
  for (var i = 0; i < sides; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / sides;
    pts.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
  }

  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[(i - 1 + pts.length) % pts.length];
    final cur = pts[i];
    final next = pts[(i + 1) % pts.length];

    final v1 = (prev - cur);
    final v2 = (next - cur);
    final l1 = v1.distance == 0 ? 1.0 : v1.distance;
    final l2 = v2.distance == 0 ? 1.0 : v2.distance;
    final c = math.min(corner, math.min(l1, l2) / 2);

    final p1 = cur + v1 / l1 * c;
    final p2 = cur + v2 / l2 * c;

    if (i == 0) {
      path.moveTo(p1.dx, p1.dy);
    } else {
      path.lineTo(p1.dx, p1.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}

/// 六边形（cookie）图标徽章，FlClash 开关/状态图标即用此形状
class CookieBadge extends StatelessWidget {
  const CookieBadge({
    super.key,
    required this.icon,
    required this.size,
    this.color,
    this.foreground,
    this.circle = false,
    this.border,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? foreground;
  final bool circle;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = color ?? cs.primary.withValues(alpha: 0.14);
    final fg = foreground ?? cs.primary;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BadgePainter(
          fill: fill,
          border: border,
          circle: circle,
        ),
        child: Center(
          child: Icon(icon, size: size * 0.52, color: fg),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.fill, this.border, this.circle = false});

  final Color fill;
  final Color? border;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final path = circle
        ? (Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height)))
        : roundedPolygonPath(size, 6, size.width * 0.22);
    canvas.drawPath(path, Paint()..color = fill);
    if (border != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) =>
      old.fill != fill || old.border != border || old.circle != circle;
}

/// FlClash 风格卡片：大圆角 + 克制阴影 + 20/18 内边距
class GlimpseCard extends StatelessWidget {
  const GlimpseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.onTap,
    this.radius = Radii.card,
    this.color,
    this.side,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Color? side;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? s.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: side ?? s.hairline.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return JellyPress(onTap: onTap, scaleTo: 0.98, child: body);
  }
}

/// 卡片标题行：图标 + 标题 + 右侧动作/箭头
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    this.icon,
    required this.title,
    this.trailing = const [],
    this.chevron = false,
  });

  final IconData? icon;
  final String title;
  final List<Widget> trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: s.textSecondary),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: s.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
        ...trailing,
        if (chevron)
          Icon(Icons.chevron_right_rounded, size: 18, color: s.textTertiary),
      ],
    );
  }
}

/// 状态胶囊：待机 / 正常 / 警告
enum ChipTone { idle, ok, warn }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = ChipTone.idle,
    this.dot = false,
    this.large = false,
  });

  final String label;
  final ChipTone tone;
  final bool dot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final (bg, fg) = switch (tone) {
      ChipTone.idle => (s.block, s.textSecondary),
      ChipTone.ok => (
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success
        ),
      ChipTone.warn => (
          AppColors.warning.withValues(alpha: 0.16),
          AppColors.warning
        ),
    };
    return Container(
      height: large ? 28 : 24,
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: fg,
              fontSize: large ? 12.5 : 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片内的次级块，比卡片低一档
class InnerBlock extends StatelessWidget {
  const InnerBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.radius = Radii.block,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? s.block,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return JellyPress(onTap: onTap, scaleTo: 0.97, child: body);
  }
}

/// 大号指标数字（等宽）
class MetricNumber extends StatelessWidget {
  const MetricNumber(
    this.value, {
    super.key,
    this.size = 26,
    this.color,
    this.suffix,
    this.suffixSize = 12,
  });

  final String value;
  final double size;
  final Color? color;
  final String? suffix;
  final double suffixSize;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: JellyNumber(
              value: value,
              style: TextStyle(
                color: color ?? s.textPrimary,
                fontSize: size,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 3),
          Text(
            suffix!,
            style: TextStyle(
              color: (color ?? s.textPrimary).withValues(alpha: 0.65),
              fontSize: suffixSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// 连接失败提示条：把错误原因直接显示出来
class ConnectionErrorBanner extends ConsumerWidget {
  const ConnectionErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(clientErrorProvider);
    final demo = ref.watch(settingsProvider).demoMode;
    if (demo || error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 15, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '连接内核失败：$error',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 页面标题行：大标题 + 右侧操作
class PageHeader extends ConsumerWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final titleScale = ref.watch(settingsProvider).titleScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: s.textPrimary,
                    fontSize: 25 * titleScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: s.textTertiary, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}


/// 分组 / 规则目标的 logo（优先用配置里的 icon，没有则用图标占位）
class ProxyLogo extends StatelessWidget {
  const ProxyLogo({super.key, required this.proxy, this.size = 30});

  final dynamic proxy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String? icon = proxy?.icon as String?;
    final fallback = CookieBadge(
      icon: Icons.layers_rounded,
      size: size,
      color: cs.primary.withValues(alpha: 0.12),
    );
    if (icon == null || icon.isEmpty) return fallback;
    return CachedLogo(url: icon, size: size, fallback: fallback);
  }
}

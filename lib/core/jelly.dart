import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// 全局触感开关（由设置页控制）
final ValueNotifier<bool> kHapticsEnabled = ValueNotifier(true);

/// 动画强度：完整 / 精简 / 关闭
enum MotionLevel { full, reduced, off }

/// 全局动画强度作用域
class MotionScope extends InheritedWidget {
  const MotionScope({
    super.key,
    required this.level,
    required super.child,
  });

  final MotionLevel level;

  static MotionLevel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    return scope?.level ?? MotionLevel.full;
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) => level != oldWidget.level;
}

SpringDescription _spring({double stiffness = 500, double dampingRatio = 0.45}) {
  // 阻尼系数 = 阻尼比 * 2 * sqrt(k * m)
  final c = dampingRatio * 2 * math.sqrt(stiffness);
  return SpringDescription(mass: 1, stiffness: stiffness, damping: c);
}

void _animateTo(AnimationController c, double target,
    {double stiffness = 500, double dampingRatio = 0.45}) {
  c.animateWith(SpringSimulation(
    _spring(stiffness: stiffness, dampingRatio: dampingRatio),
    c.value,
    target,
    c.velocity,
  ));
}

/// 包裹所有可点元素：按下缩放 0.96，弹簧回弹，可选触觉反馈
class JellyPress extends StatefulWidget {
  const JellyPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleTo = 0.96,
    this.haptic = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleTo;
  final bool haptic;
  final bool enabled;

  @override
  State<JellyPress> createState() => _JellyPressState();
}

class _JellyPressState extends State<JellyPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, value: 1.0, duration: const Duration(milliseconds: 220));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (!widget.enabled) return;
    if (MotionScope.of(context) == MotionLevel.off) return;
    _animateTo(_c, widget.scaleTo, stiffness: 900, dampingRatio: 0.9);
  }

  void _up() {
    if (!widget.enabled) return;
    if (MotionScope.of(context) == MotionLevel.off) return;
    _animateTo(_c, 1.0, stiffness: 500, dampingRatio: 0.45);
  }

  @override
  Widget build(BuildContext context) {
    final level = MotionScope.of(context);
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) {
          _up();
          if (widget.onTap != null) {
            if (widget.haptic &&
                kHapticsEnabled.value &&
                level != MotionLevel.off) {
              HapticFeedback.lightImpact();
            }
            widget.onTap!();
          }
        },
        onTapCancel: _up,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final v = level == MotionLevel.off ? 1.0 : _c.value;
            // 静止时不加 Transform，减少图层与重绘
            if ((v - 1.0).abs() < 0.001) return child!;
            // 凝光：按压越深，光晕越向外扩散
            return Transform.scale(scale: v, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// 列表项 / 卡片入场：位移 12dp + scale 0.96，可 stagger
class JellyEntry extends StatefulWidget {
  const JellyEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.staggerMs = 30,
    this.offsetY = 12,
  });

  final Widget child;
  final int index;
  final int staggerMs;
  final double offsetY;

  @override
  State<JellyEntry> createState() => _JellyEntryState();
}

class _JellyEntryState extends State<JellyEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _v = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = widget.staggerMs * widget.index.clamp(0, 12);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = MotionScope.of(context);
    // 长列表基本不做入场动画，避免一次性起几十个控制器
    if (level == MotionLevel.off || widget.index > 12) return widget.child;
    final t = level == MotionLevel.reduced
        ? const AlwaysStoppedAnimation<double>(1.0)
        : _v;
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final p = t.value;
        if (p >= 0.999) return child!;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - p)),
            child: Transform.scale(scale: 0.96 + 0.04 * p, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 页面切换：淡入 + 8dp 位移 + 轻微 scale，260ms
Route<T> jellyRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final p = curved.value;
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - p)),
              child: Transform.scale(scale: 0.995 + 0.005 * p, child: child),
            ),
          );
        },
        child: child,
      );
    },
  );
}

/// 数字变化时的弹跳（用于延时结果）
class JellyNumber extends StatelessWidget {
  const JellyNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 420),
  });

  final String value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final level = MotionScope.of(context);
    if (level == MotionLevel.off) {
      return Text(value, style: style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (context, t, _) {
        final scale = 1 + 0.12 * math.sin(t * math.pi) * (t < 0.5 ? 1 : 0.4);
        return Transform.scale(scale: scale, child: Text(value, style: style));
      },
    );
  }
}

/// 底部弹层：升到顶再回落 4dp
Future<T?> showJellySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    enableDrag: dismissible,
    isDismissible: dismissible,
    builder: (ctx) => _JellySheetBody(child: builder(ctx)),
  );
}

class _JellySheetBody extends StatefulWidget {
  const _JellySheetBody({required this.child});

  final Widget child;

  @override
  State<_JellySheetBody> createState() => _JellySheetBodyState();
}

class _JellySheetBodyState extends State<_JellySheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final p = _c.value;
        // 轻微过冲：先到 -4 再回到 0
        final lift = -4 * math.sin(p * math.pi) * 0.6;
        return Transform.translate(
          offset: Offset(0, (1 - p) * 120 + lift),
          child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
          boxShadow: cardShadow(context),
        ),
        child: widget.child,
      ),
    );
  }
}


/// 居中悬浮弹窗：弹簧放大进入，替代底部滑出的 sheet
Future<T?> showJellyDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double maxWidth = 360,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (ctx, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      final s = surfacesOf(ctx);
      return AnimatedBuilder(
        animation: curved,
        builder: (ctx2, _) {
          final p = curved.value.clamp(0.0, 1.2);
          return Opacity(
            opacity: (p / 1.05).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.86 + 0.14 * p,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight:
                        MediaQuery.of(ctx).size.height * 0.72,
                  ),
                  child: Material(
                    color: s.card,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: builder(ctx),
                  ),
                ),
              ),
            ),
          );
        },
        child: const SizedBox.shrink(),
      );
    },
  );
}

/// 从点击的卡片位置「长」成整块面板（容器变换，类似 iOS 打开 App）
Future<T?> showExpandingSheet<T>({
  required BuildContext context,
  required Rect origin,
  required WidgetBuilder builder,
  double heightFactor = 0.56,
}) {
  final screen = MediaQuery.of(context).size;
  final panelW = screen.width - 64;
  final panelH = screen.height * heightFactor;
  // 居中悬浮，不贴屏幕底部
  final endRect = Rect.fromLTWH(
    (screen.width - panelW) / 2,
    (screen.height - panelH) / 2,
    panelW,
    panelH,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, animation, secondary) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: curved,
        builder: (ctx, _) {
          final t = curved.value.clamp(0.0, 1.0);
          final rect = Rect.lerp(origin, endRect, t)!;
          final radius =
              ui.lerpDouble(origin.width * 0.2, Radii.sheet, t)!;
          return Stack(
            children: [
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Material(
                    // 不跟随「界面不透明度」，保证内容清晰可读
                    color: Color.alphaBlend(
                      surfacesOf(ctx).card.withValues(alpha: 1),
                      surfacesOf(ctx).page.withValues(alpha: 1),
                    ),
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minWidth: endRect.width,
                      maxWidth: endRect.width,
                      minHeight: endRect.height,
                      maxHeight: endRect.height,
                      child: Opacity(
                        opacity: ((t - 0.2) / 0.8).clamp(0.0, 1.0),
                        child: builder(ctx),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: const SizedBox.shrink(),
      );
    },
  );
}


/// 带果冻反馈的图标按钮（替代原生 IconButton）
class JellyIconButton extends StatelessWidget {
  const JellyIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 18,
    this.color,
    this.padding = const EdgeInsets.all(7),
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return JellyPress(
      haptic: false,
      enabled: onPressed != null,
      onTap: onPressed,
      scaleTo: 0.8,
      child: Padding(
        padding: padding,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

/// 带果冻反馈的文字按钮
class JellyTextButton extends StatelessWidget {
  const JellyTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return JellyPress(
      haptic: false,
      enabled: onPressed != null,
      onTap: onPressed,
      scaleTo: 0.92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

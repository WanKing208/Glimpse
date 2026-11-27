import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/bg_image.dart';
import 'core/jelly.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'pages/connections_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/logs_page.dart';
import 'pages/proxies_page.dart';
import 'pages/rules_page.dart';
import 'pages/settings_page.dart';

class Tabs {
  static const dashboard = 0;
  static const proxies = 1;
  static const connections = 2;
  static const rules = 3;
  static const logs = 4;
  static const settings = 5;
}

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int i) => state = i;
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

final _items = [
  _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, tr('仪表盘')),
  _NavItem(Icons.swap_vert_circle_outlined, Icons.swap_vert_circle, tr('代理')),
  _NavItem(Icons.link_outlined, Icons.link, tr('连接')),
  _NavItem(Icons.rule_outlined, Icons.rule, tr('规则')),
  _NavItem(Icons.terminal_outlined, Icons.terminal, tr('日志')),
  _NavItem(Icons.tune_outlined, Icons.tune, tr('设置')),
];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );

  /// 已构建过的页面：代理页常驻，其余按需（懒加载）
  final Set<int> _built = {Tabs.proxies};

  /// 预构建相邻页，避免滑动到未构建页时掉帧
  void _prebuildAround(int index) {
    final next = <int>{
      if (index - 1 >= 0) index - 1,
      if (index + 1 < Tabs.settings + 1) index + 1,
    };
    final added = next.difference(_built);
    if (added.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _built.addAll(added));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _prebuildAround(ref.read(shellTabProvider));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabProvider);

    ref.listen<int>(shellTabProvider, (prev, next) {
      ref.read(activeTabProvider.notifier).set(next);
      // 淡入 + 轻微回弹，替代拖动式滑动
      _anim.forward(from: 0);
    });
    final proxyTab = ref.watch(proxyTabProvider);
    final openedGroup = ref.watch(proxyOpenedProvider);
    final settings = ref.watch(settingsProvider);

    _built.add(index);

    final hasSubPage =
        index == Tabs.proxies && (openedGroup != null || proxyTab == 1);

    const pages = [
      DashboardPage(),
      ProxiesPage(),
      ConnectionsPage(),
      RulesPage(),
      LogsPage(),
      SettingsPage(),
    ];

    final bg = settings.backgroundImage.trim();
    Widget? background;
    if (bg.isNotEmpty) {
      background = bg.startsWith('http')
          ? Image.network(
              bg,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : localBackground(bg);
    }

    final s = surfacesOf(context);

    return PopScope(
      canPop: !hasSubPage,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (openedGroup != null) {
          ref.read(proxyOpenedProvider.notifier).set(null);
        } else {
          ref.read(proxyTabProvider.notifier).set(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            background == null ? null : s.page.withValues(alpha: 0.94),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (background != null) ...[
              settings.bgBlur > 0
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: settings.bgBlur,
                        sigmaY: settings.bgBlur,
                      ),
                      child: background,
                    )
                  : background,
              Container(
                color: Colors.black.withValues(
                    alpha: settings.backgroundDim.clamp(0.0, 0.8)),
              ),
            ],
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.velocity.pixelsPerSecond.dx;
                if (v.abs() < 260) return;
                final next = v < 0 ? index + 1 : index - 1;
                if (next >= 0 && next <= Tabs.settings) {
                  ref.read(shellTabProvider.notifier).set(next);
                }
              },
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) {
                  final t = _anim.value.clamp(0.0, 1.0);
                  // 弹性曲线：先放大再回弹，和底栏的手感一致
                  final e = Curves.elasticOut.transform(t);
                  final scale = 1 + 0.05 * (1 - e);
                  return Opacity(
                    opacity: 0.72 + 0.28 * Curves.easeOutCubic.transform(t),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0; i <= Tabs.settings; i++)
                      Offstage(
                        offstage: i != index,
                        child: RepaintBoundary(
                          child: _built.contains(i)
                              ? pages[i]
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _FloatingNavBar(
          index: index,
          radius: settings.navRadius,
          opacity: settings.navOpacity,
          glass: settings.navGlass,
          onSelect: (i) => ref.read(shellTabProvider.notifier).set(i),
        ),
      ),
    );
  }
}

/// 悬浮底栏：弧度 / 透明度 / 玻璃效果可调，选中胶囊弹簧滑动
class _FloatingNavBar extends StatefulWidget {
  const _FloatingNavBar({
    required this.index,
    required this.radius,
    required this.opacity,
    required this.glass,
    required this.onSelect,
  });

  final int index;
  final double radius;
  final double opacity;
  final bool glass;
  final ValueChanged<int> onSelect;

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final AnimationController _pos = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.index.toDouble(),
    lowerBound: 0,
    upperBound: (_items.length - 1).toDouble(),
  );

  @override
  void didUpdateWidget(covariant _FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _pulse.forward(from: 0);
      _pos.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 480, damping: 26),
        _pos.value,
        widget.index.toDouble(),
        _pos.velocity,
      ));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;
    final radius = widget.radius.clamp(0.0, 34.0);
    final opacity = widget.opacity.clamp(0.35, 1.0);

    final bar = Container(
        height: 62,
        decoration: BoxDecoration(
          color: (dark ? s.card : Colors.white).withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: s.hairline.withValues(alpha: 0.5),
            width: 0.7,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / _items.length;
            return AnimatedBuilder(
              animation: _pos,
              builder: (context, _) {
                final left = slot * _pos.value;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: left + slot * 0.045,
                      width: slot * 0.91,
                      top: 6,
                      bottom: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.13),
                          borderRadius:
                              BorderRadius.circular(math.max(6, radius - 9)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: _items[i],
                              selected: i == widget.index,
                              accent: cs.primary,
                              idle: s.textTertiary,
                              onTap: () => widget.onSelect(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
    );

    // 只模糊底栏本体，外围不再做过渡模糊
    Widget panel = bar;
    if (widget.glass) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: panel,
        ),
      );
    }

    // 缩放放在裁剪外层，点击放大时不会被裁掉
    panel = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value.clamp(0.0, 1.0);
        final s = 1 + 0.04 * math.sin(t * math.pi);
        return Transform.scale(scale: s, child: child);
      },
      child: panel,
    );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom * 0.5),
        child: panel,
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.idle,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final Color accent;
  final Color idle;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _NavButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _c.animateWith(SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 380, damping: 12),
          0,
          1,
          0,
        ));
      } else {
        _c.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = MotionScope.of(context);
    return JellyPress(
      haptic: false,
      onTap: widget.onTap,
      scaleTo: 0.88,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final p = _c.value.clamp(0.0, 1.0);
          final bounce = level == MotionLevel.off
              ? 1.0
              : (widget.selected ? 1.12 : 1.0) + 0.18 * math.sin(p * math.pi);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: bounce,
                child: Icon(
                  widget.selected ? widget.item.activeIcon : widget.item.icon,
                  size: 21,
                  color: widget.selected ? widget.accent : widget.idle,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.0,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected ? widget.accent : widget.idle,
                ),
                child: Text(widget.item.label),
              ),
            ],
          );
        },
      ),
    );
  }
}



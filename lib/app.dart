import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/jelly.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'shell.dart';

/// 全局滚动行为：弹性回弹
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  // 关掉 Android 的边缘发光，只留回弹，滑动更顺
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class GlimpseApp extends ConsumerStatefulWidget {
  const GlimpseApp({super.key});

  @override
  ConsumerState<GlimpseApp> createState() => _GlimpseAppState();
}

class _GlimpseAppState extends ConsumerState<GlimpseApp>
    with WidgetsBindingObserver {
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 静默看门狗：实时流若 15 秒没有新数据（半死连接），强制重建
    _watchdog = Timer.periodic(const Duration(seconds: 8), (_) {
      final idle = DateTime.now().difference(lastLiveDataAt);
      if (idle > const Duration(seconds: 15)) {
        lastLiveDataAt = DateTime.now();
        ref.invalidate(trafficProvider);
        ref.invalidate(memoryProvider);
        ref.invalidate(connectionsProvider);
      }
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 长连接在后台容易被系统掐断，回前台直接重建
      ref.invalidate(trafficProvider);
      ref.invalidate(memoryProvider);
      ref.invalidate(connectionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final effectiveTheme = kShots ? ThemeMode.dark : settings.themeMode;
    kHapticsEnabled.value = settings.haptics;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // 壁纸取色：Android 12+ 可用，取不到时回落到手动强调色
        final lightSeed = settings.useWallpaper && lightDynamic != null
            ? lightDynamic.primary
            : Color(settings.accentColor);
        final darkSeed = settings.useWallpaper && darkDynamic != null
            ? darkDynamic.primary
            : Color(settings.accentColor);

        return MaterialApp(
          title: 'Glimpse',
          debugShowCheckedModeBanner: false,
          themeMode: effectiveTheme,
          theme: AppTheme.build(
            brightness: Brightness.light,
            seedColor: lightSeed,
            surfaceOpacity: settings.surfaceOpacity,
            fontFamily: settings.fontFamily,
            tone: _toneOf(settings.pageTone),
            customTone: Color(settings.toneColor),
          ),
          darkTheme: AppTheme.build(
            brightness: Brightness.dark,
            seedColor: darkSeed,
            surfaceOpacity: settings.surfaceOpacity,
            fontFamily: settings.fontFamily,
            tone: _toneOf(settings.pageTone),
            customTone: Color(settings.toneColor),
          ),
          scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) {
        gLang = settings.language;
        final media = MediaQuery.of(context);
        // 系统「减少动画」时自动降为精简
        final systemReduced = media.disableAnimations;
        var level = settings.motion;
        if (systemReduced && level == MotionLevel.full) {
          level = MotionLevel.reduced;
        }
        final scaled = media.copyWith(
          textScaler: TextScaler.linear(
            media.textScaler.scale(1) * settings.fontScale,
          ),
        );
        return MediaQuery(
          data: scaled,
          child: MotionScope(level: level, child: child ?? const SizedBox()),
        );
      },
          home: const HomeShell(),
        );
      },
    );
  }
}


PageTone _toneOf(String v) => switch (v) {
      'navy' => PageTone.navy,
      'forest' => PageTone.forest,
      'violet' => PageTone.violet,
      'amber' => PageTone.amber,
      'light' => PageTone.light,
      'custom' => PageTone.custom,
      _ => PageTone.ink,
    };

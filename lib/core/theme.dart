import 'package:material_ui/material_ui.dart';

/// 整页配色方案
enum PageTone { ink, navy, forest, violet, amber, light, custom }

class _ToneColors {
  const _ToneColors(this.page, this.card, this.block, this.inset, this.hairline);
  final Color page;
  final Color card;
  final Color block;
  final Color inset;
  final Color hairline;
}

const _tones = <PageTone, _ToneColors>{
  PageTone.ink: _ToneColors(Color(0xFF0B0B0F), Color(0xFF1C1C1E),
      Color(0xFF25262B), Color(0xFF141417), Color(0xFF38383A)),
  PageTone.navy: _ToneColors(Color(0xFF0A1020), Color(0xFF141E33),
      Color(0xFF1D2942), Color(0xFF0D1526), Color(0xFF2A3853)),
  PageTone.forest: _ToneColors(Color(0xFF0A1410), Color(0xFF13211A),
      Color(0xFF1B2E24), Color(0xFF0D1812), Color(0xFF26402F)),
  PageTone.violet: _ToneColors(Color(0xFF120A1E), Color(0xFF1E1630),
      Color(0xFF2A2042), Color(0xFF160E24), Color(0xFF382A52)),
  PageTone.amber: _ToneColors(Color(0xFF14100C), Color(0xFF221B15),
      Color(0xFF2E251C), Color(0xFF18130E), Color(0xFF413324)),
  PageTone.light: _ToneColors(Color(0xFFF2F2F7), Color(0xFFFFFFFF),
      Color(0xFFE2E4EC), Color(0xFFD6D9E3), Color(0xFFD2D5E0)),
};

/// FlClash / iOS 系统色
class AppColors {
  static const primary = Color(0xFF007AFF);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const danger = Color(0xFFFF3B30);

  /// FlClash 的强调色列表（iOS 27 系统色顺序）
  static const accents = [
    Color(0xFF007AFF),
    Color(0xFFCB30E0),
    Color(0xFFFF2D55),
    Color(0xFFFF383C),
    Color(0xFFFF8D28),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF8E8E93),
  ];
}

class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.page,
    required this.card,
    required this.block,
    required this.inset,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color page;
  final Color card;
  final Color block;
  final Color inset;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  @override
  AppSurfaces copyWith({
    Color? page,
    Color? card,
    Color? block,
    Color? inset,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
  }) =>
      AppSurfaces(
        page: page ?? this.page,
        card: card ?? this.card,
        block: block ?? this.block,
        inset: inset ?? this.inset,
        hairline: hairline ?? this.hairline,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
      );

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) return this;
    return AppSurfaces(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      block: Color.lerp(block, other.block, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

/// 圆角规范（对齐 FlClash 的卡片）
class Radii {
  static const card = 20.0;
  static const block = 14.0;
  static const row = 12.0;
  static const pill = 999.0;
  static const sheet = 28.0;
}

class Rows {
  static const compact = 44.0;
  static const normal = 56.0;
  static const loose = 68.0;
}

/// 延时配色，与 FlClash 的 DelayColorScheme 一致：
/// null 无 / <0 失败(红) / <600 良好(绿) / >=600 一般(橙)
Color delayColor(int? delay, ColorScheme cs) {
  if (delay == null) return cs.outline;
  if (delay == 0) return cs.outline; // 0 视为不可用，灰色
  if (delay < 0) return AppColors.danger;
  if (delay < 300) return AppColors.success; // 1-299 绿
  if (delay < 700) return AppColors.warning; // 300-699 黄
  return AppColors.danger; // 700+ 红
}

AppSurfaces surfacesOf(BuildContext context) =>
    Theme.of(context).extension<AppSurfaces>()!;

/// 从色盘选的一个颜色推导出四级表面色
_ToneColors _deriveTone(Color base) {
  final hsl = HSLColor.fromColor(base);
  Color at(double l, [double s = 1.0]) => hsl
      .withLightness(l.clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * s).clamp(0.0, 1.0))
      .toColor();
  return _ToneColors(
    at(0.07),
    at(0.13),
    at(0.19),
    at(0.05),
    at(0.26, 0.6),
  );
}

class AppTheme {
  static ThemeData build({
    required Brightness brightness,
    Color? seedColor,
    double surfaceOpacity = 1.0,
    String fontFamily = 'system',
    PageTone tone = PageTone.ink,
    Color? customTone,
  }) {
    final dark = brightness == Brightness.dark;
    final seed = seedColor ?? AppColors.primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      // FlClash 直接用种子色当主色，不走 M3 的色调映射
      primary: seed,
      onPrimary: Colors.white,
      primaryContainer: seed.withValues(alpha: 0.14),
      onPrimaryContainer: seed,
    );

    final op = surfaceOpacity.clamp(0.45, 1.0);
    final _ToneColors tc;
    if (!dark && tone != PageTone.custom) {
      // 亮色模式统一走浅色板，保证顶栏控件/搜索框对比度
      tc = _tones[PageTone.light]!;
    } else if (tone == PageTone.custom && customTone != null) {
      tc = _deriveTone(customTone);
    } else {
      tc = _tones[tone] ?? _tones[PageTone.ink]!;
    }
    final surfaces = AppSurfaces(
      page: tc.page.withValues(alpha: op),
      card: tc.card.withValues(alpha: op),
      block: tc.block.withValues(alpha: op),
      inset: tc.inset.withValues(alpha: op),
      hairline: tc.hairline,
      textPrimary: dark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
      textSecondary: dark ? const Color(0xFFAEAEB2) : const Color(0xFF5A5A5F),
      textTertiary: dark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
    );

    final base = Typography.material2021(platform: TargetPlatform.android).black
        .apply(
          bodyColor: surfaces.textPrimary,
          displayColor: surfaces.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaces.page,
      extensions: [surfaces],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      textTheme: base.apply(
        fontFamily: switch (fontFamily) {
          'serif' => 'serif',
          'mono' => 'monospace',
          _ => null,
        },
      ).copyWith(
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaces.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: surfaces.textPrimary,
        titleTextStyle: TextStyle(
          color: surfaces.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: surfaces.hairline,
        thickness: 0.8,
        space: 0.8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : (dark ? const Color(0xFF39393D) : const Color(0xFFE5E5EA)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.block),
        ),
      ),
    );
  }
}

/// 卡片阴影：FlClash 的 e1 很克制
List<BoxShadow> cardShadow(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: dark ? const Color(0x33000000) : const Color(0x0A000000),
      blurRadius: 6,
      offset: const Offset(0, 3),
      spreadRadius: -2,
    ),
  ];
}


/// 卡片默认圆角（各页面统一引用）
extension SurfacesRadius on AppSurfaces {
  double get cardRadiusFallback => 16;
}

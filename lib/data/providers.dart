import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/geo.dart';
import '../core/jelly.dart';
import 'client.dart';
import 'demo.dart';
import 'models.dart';

// ---------------------------------------------------------------- 设置

/// 一个后台（控制器）配置
class Backend {
  const Backend({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.secret,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String secret;

  Backend copyWith({String? name, String? baseUrl, String? secret}) => Backend(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        secret: secret ?? this.secret,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': baseUrl, 'secret': secret};

  factory Backend.fromJson(Map<String, dynamic> j) => Backend(
        id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? '未命名',
        baseUrl: j['url']?.toString() ?? '',
        secret: j['secret']?.toString() ?? '',
      );
}


class Settings {
  const Settings({
    this.baseUrl = 'http://127.0.0.1:9090',
    this.secret = '',
    this.demoMode = false,
    this.themeMode = ThemeMode.system,
    this.motion = MotionLevel.full,
    this.sortMode = 'config',
    this.nodeSortMode = 'config',
    this.proxyLayout = 'tab',
    this.hideTimeout = false,
    this.density = 'normal',
    this.connView = 'table',
    this.showNodeName = true,
    this.showDelay = true,
    this.showTraffic = true,
    this.showMemory = true,
    this.showUpdatedAt = true,
    this.accentColor = 0xFF007AFF,
    this.proxyColumns = 3,
    this.proxyCardSize = 'medium',
    this.cardHeight = 1.15,
    this.proxyLogoSize = 30.0,
    this.groupByProvider = false,
    this.showGlobalGroup = true,
    this.showPerfOverlay = false,
    this.pageTone = 'ink',
    this.fontScale = 1.0,
    this.language = 'zh',
    this.titleScale = 1.0,
    this.toneColor = 0xFF1B2430,
    this.backends = const [],
    this.activeBackendId = '',
    this.cardRadius = 16.0,
    this.nodeRadius = 13.0,
    this.nodeFontSize = 11.5,
    this.nodeGap = 4.0,
    this.nodePadV = 9.0,
    this.delayTestUrl = 'https://www.gstatic.com/generate_204',
    this.delayTestMode = 'app',
    this.useWallpaper = false,
    this.navRadius = 28.0,
    this.navOpacity = 0.82,
    this.navGlass = true,
    this.backgroundImage = '',
    this.backgroundDim = 0.35,
    this.chartStyle = 'bar',
    this.chartUpColor = 0xFF007AFF,
    this.chartDownColor = 0xFF34C759,
    this.surfaceOpacity = 1.0,
    this.sheetGlass = true,
    this.sheetBlur = 18.0,
    this.bgBlur = 0.0,
    this.fontFamily = 'system',
    this.haptics = true,
  });

  final String baseUrl;
  final String secret;
  final bool demoMode;
  final ThemeMode themeMode;
  final MotionLevel motion;
  final String sortMode;

  /// 节点排序（与分组排序分开）
  final String nodeSortMode;
  final String proxyLayout;
  final bool hideTimeout;
  final String density;
  final String connView;

  final bool showNodeName;
  final bool showDelay;
  final bool showTraffic;
  final bool showMemory;
  final bool showUpdatedAt;

  /// 强调色（ARGB）
  final int accentColor;

  /// 代理分组网格列数：1/2/3
  final int proxyColumns;

  /// 代理卡片尺寸：small / medium / large
  final String proxyCardSize;

  /// 分组卡片高度系数（越大越扁，默认比之前小一圈）
  final double cardHeight;

  /// 分组/机场 logo 尺寸
  final double proxyLogoSize;

  /// 节点列表里按机场（供应商）分组显示
  final bool groupByProvider;

  /// 是否显示 GLOBAL 分组（仅在全局模式下显示，并排在最后）
  final bool showGlobalGroup;

  /// 是否显示 Flutter 性能浮层
  final bool showPerfOverlay;

  /// 整页配色：ink/navy/forest/violet/amber/light/custom
  final String pageTone;

  /// 正文字体缩放
  final double fontScale;

  /// 界面语言：zh / en
  final String language;

  /// 大字号（标题/分组名）缩放
  final double titleScale;

  /// 自定义页面配色（ARGB）
  final int toneColor;

  /// 多个后台配置
  final List<Backend> backends;

  /// 当前使用的后台 id
  final String activeBackendId;

  Backend? get activeBackend {
    if (backends.isEmpty) return null;
    for (final b in backends) {
      if (b.id == activeBackendId) return b;
    }
    return backends.first;
  }

  /// 分组卡圆角
  final double cardRadius;

  /// 节点卡圆角
  final double nodeRadius;

  /// 节点名称字号
  final double nodeFontSize;

  /// 节点卡上下间距
  final double nodeGap;

  /// 节点卡内部上下留白
  final double nodePadV;

  /// 测延时用的地址
  final String delayTestUrl;

  /// 测速方式：app = 用上面的地址，config = 交给内核按配置测
  final String delayTestMode;

  /// 是否使用系统壁纸取色
  final bool useWallpaper;

  /// 底栏圆角
  final double navRadius;
  /// 底栏不透明度
  final double navOpacity;
  /// 底栏毛玻璃
  final bool navGlass;
  /// 背景图片（本地路径或 http 地址）
  final String backgroundImage;
  /// 背景压暗程度
  final double backgroundDim;
  /// 流量图样式：line / bar / dot
  final String chartStyle;
  final int chartUpColor;
  final int chartDownColor;

  /// 界面整体不透明度（卡片/页面）
  final double surfaceOpacity;
  /// 悬浮窗磨砂
  final bool sheetGlass;

  /// 悬浮窗磨砂强度（模糊半径）
  final double sheetBlur;
  /// 背景图模糊半径
  final double bgBlur;
  /// 字体：system / serif / mono
  final String fontFamily;
  /// 触感反馈
  final bool haptics;

  Settings copyWith({
    String? baseUrl,
    String? secret,
    bool? demoMode,
    ThemeMode? themeMode,
    MotionLevel? motion,
    String? sortMode,
    String? nodeSortMode,
    String? proxyLayout,
    bool? hideTimeout,
    String? density,
    String? connView,
    bool? showNodeName,
    bool? showDelay,
    bool? showTraffic,
    bool? showMemory,
    bool? showUpdatedAt,
    int? accentColor,
    int? proxyColumns,
    String? proxyCardSize,
    double? cardHeight,
    double? proxyLogoSize,
    bool? groupByProvider,
    String? delayTestUrl,
    String? delayTestMode,
    bool? useWallpaper,
    double? navRadius,
    double? navOpacity,
    bool? navGlass,
    String? backgroundImage,
    double? backgroundDim,
    String? chartStyle,
    int? chartUpColor,
    int? chartDownColor,
    double? surfaceOpacity,
    bool? sheetGlass,
    double? sheetBlur,
    double? bgBlur,
    String? fontFamily,
    bool? haptics,
    bool? showGlobalGroup,
    bool? showPerfOverlay,
    String? pageTone,
    double? fontScale,
    String? language,
    double? titleScale,
    int? toneColor,
    List<Backend>? backends,
    String? activeBackendId,
    double? cardRadius,
    double? nodeRadius,
    double? nodeFontSize,
    double? nodeGap,
    double? nodePadV,
  }) {
    return Settings(
      baseUrl: baseUrl ?? this.baseUrl,
      secret: secret ?? this.secret,
      demoMode: demoMode ?? this.demoMode,
      themeMode: themeMode ?? this.themeMode,
      motion: motion ?? this.motion,
      sortMode: sortMode ?? this.sortMode,
      nodeSortMode: nodeSortMode ?? this.nodeSortMode,
      proxyLayout: proxyLayout ?? this.proxyLayout,
      hideTimeout: hideTimeout ?? this.hideTimeout,
      density: density ?? this.density,
      connView: connView ?? this.connView,
      showNodeName: showNodeName ?? this.showNodeName,
      showDelay: showDelay ?? this.showDelay,
      showTraffic: showTraffic ?? this.showTraffic,
      showMemory: showMemory ?? this.showMemory,
      showUpdatedAt: showUpdatedAt ?? this.showUpdatedAt,
      accentColor: accentColor ?? this.accentColor,
      proxyColumns: proxyColumns ?? this.proxyColumns,
      proxyCardSize: proxyCardSize ?? this.proxyCardSize,
      cardHeight: cardHeight ?? this.cardHeight,
      proxyLogoSize: proxyLogoSize ?? this.proxyLogoSize,
      groupByProvider: groupByProvider ?? this.groupByProvider,
      delayTestUrl: delayTestUrl ?? this.delayTestUrl,
      delayTestMode: delayTestMode ?? this.delayTestMode,
      useWallpaper: useWallpaper ?? this.useWallpaper,
      navRadius: navRadius ?? this.navRadius,
      navOpacity: navOpacity ?? this.navOpacity,
      navGlass: navGlass ?? this.navGlass,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundDim: backgroundDim ?? this.backgroundDim,
      chartStyle: chartStyle ?? this.chartStyle,
      chartUpColor: chartUpColor ?? this.chartUpColor,
      chartDownColor: chartDownColor ?? this.chartDownColor,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      sheetGlass: sheetGlass ?? this.sheetGlass,
      sheetBlur: sheetBlur ?? this.sheetBlur,
      bgBlur: bgBlur ?? this.bgBlur,
      fontFamily: fontFamily ?? this.fontFamily,
      haptics: haptics ?? this.haptics,
      showGlobalGroup: showGlobalGroup ?? this.showGlobalGroup,
      showPerfOverlay: showPerfOverlay ?? this.showPerfOverlay,
      pageTone: pageTone ?? this.pageTone,
      fontScale: fontScale ?? this.fontScale,
      language: language ?? this.language,
      titleScale: titleScale ?? this.titleScale,
      toneColor: toneColor ?? this.toneColor,
      backends: backends ?? this.backends,
      activeBackendId: activeBackendId ?? this.activeBackendId,
      cardRadius: cardRadius ?? this.cardRadius,
      nodeRadius: nodeRadius ?? this.nodeRadius,
      nodeFontSize: nodeFontSize ?? this.nodeFontSize,
      nodeGap: nodeGap ?? this.nodeGap,
      nodePadV: nodePadV ?? this.nodePadV,
    );
  }
}

List<Backend> _loadBackends() {
  final raw = prefs.getString('glimpse.backends');
  if (raw != null && raw.isNotEmpty) {
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Backend.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
  }
  // 迁移：老的单地址配置
  final url = prefs.getString('glimpse.baseUrl') ?? '';
  final secret = prefs.getString('glimpse.secret') ?? '';
  if (url.isEmpty) return const [];
  return [
    Backend(id: 'default', name: '默认', baseUrl: url, secret: secret),
  ];
}

/// 由 main() 在 runApp 之前注入
late SharedPreferences prefs;

/// 生成文档截图时（--dart-define=SHOTS=true）为 true
const kShots = bool.fromEnvironment('SHOTS');

const _kPrefix = 'glimpse.';

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    return Settings(
      baseUrl: prefs.getString('${_kPrefix}baseUrl') ?? 'http://127.0.0.1:9090',
      secret: prefs.getString('${_kPrefix}secret') ?? '',
      // 仅用于生成文档截图：flutter build web --dart-define=SHOTS=true
      demoMode: kShots,
      themeMode: _themeFrom(prefs.getString('${_kPrefix}theme')),
      motion: _motionFrom(prefs.getString('${_kPrefix}motion')),
      sortMode: prefs.getString('${_kPrefix}sort') ?? 'config',
      nodeSortMode: prefs.getString('${_kPrefix}nodeSort') ?? 'config',
      proxyLayout: prefs.getString('${_kPrefix}layout') ?? 'tab',
      hideTimeout: prefs.getBool('${_kPrefix}hideTimeout') ?? false,
      density: prefs.getString('${_kPrefix}density') ?? 'normal',
      connView: prefs.getString('${_kPrefix}connView') ?? 'table',
      showNodeName: prefs.getBool('${_kPrefix}w.nodeName') ?? true,
      showDelay: prefs.getBool('${_kPrefix}w.delay') ?? true,
      showTraffic: prefs.getBool('${_kPrefix}w.traffic') ?? true,
      showMemory: prefs.getBool('${_kPrefix}w.memory') ?? true,
      showUpdatedAt: prefs.getBool('${_kPrefix}w.updatedAt') ?? true,
      accentColor: prefs.getInt('${_kPrefix}accent') ?? 0xFF007AFF,
      proxyColumns: kShots ? 2 : prefs.getInt('${_kPrefix}proxyCols') ?? 3,
      proxyCardSize: prefs.getString('${_kPrefix}cardSize') ?? 'medium',
      cardHeight: prefs.getDouble('${_kPrefix}cardHeight') ?? 1.15,
      proxyLogoSize: prefs.getDouble('${_kPrefix}logoSize') ?? 30.0,
      groupByProvider: prefs.getBool('${_kPrefix}groupByProvider') ?? false,
      delayTestUrl: prefs.getString('${_kPrefix}delayUrl') ??
          'https://www.gstatic.com/generate_204',
      delayTestMode: prefs.getString('${_kPrefix}delayMode') ?? 'app',
      useWallpaper: prefs.getBool('${_kPrefix}wallpaper') ?? false,
      navRadius: prefs.getDouble('${_kPrefix}navRadius') ?? 28.0,
      navOpacity: prefs.getDouble('${_kPrefix}navOpacity') ?? 0.82,
      navGlass: prefs.getBool('${_kPrefix}navGlass') ?? true,
      backgroundImage: prefs.getString('${_kPrefix}bg') ?? '',
      backgroundDim: prefs.getDouble('${_kPrefix}bgDim') ?? 0.35,
      chartStyle: prefs.getString('${_kPrefix}chartStyle') ?? 'bar',
      chartUpColor: prefs.getInt('${_kPrefix}chartUp') ?? 0xFF007AFF,
      chartDownColor: prefs.getInt('${_kPrefix}chartDown') ?? 0xFF34C759,
      surfaceOpacity: prefs.getDouble('${_kPrefix}surfOpacity') ?? 1.0,
      sheetGlass: prefs.getBool('${_kPrefix}sheetGlass') ?? true,
      sheetBlur: prefs.getDouble('${_kPrefix}sheetBlur') ?? 18.0,
      bgBlur: prefs.getDouble('${_kPrefix}bgBlur') ?? 0.0,
      fontFamily: prefs.getString('${_kPrefix}font') ?? 'system',
      haptics: prefs.getBool('${_kPrefix}haptics') ?? true,
      showGlobalGroup: prefs.getBool('${_kPrefix}showGlobal') ?? true,
      showPerfOverlay: prefs.getBool('${_kPrefix}perfOverlay') ?? false,
      pageTone: prefs.getString('${_kPrefix}pageTone') ?? 'ink',
      fontScale: prefs.getDouble('${_kPrefix}fontScale') ?? 1.0,
      language: prefs.getString('${_kPrefix}language') ?? 'zh',
      titleScale: prefs.getDouble('${_kPrefix}titleScale') ?? 1.0,
      toneColor: prefs.getInt('${_kPrefix}toneColor') ?? 0xFF1B2430,
      backends: _loadBackends(),
      activeBackendId: prefs.getString('${_kPrefix}activeBackend') ?? '',
      cardRadius: prefs.getDouble('${_kPrefix}cardRadius') ?? 16.0,
      nodeRadius: prefs.getDouble('${_kPrefix}nodeRadius') ?? 13.0,
      nodeFontSize: prefs.getDouble('${_kPrefix}nodeFont') ?? 11.5,
      nodeGap: prefs.getDouble('${_kPrefix}nodeGap') ?? 4.0,
      nodePadV: prefs.getDouble('${_kPrefix}nodePadV') ?? 9.0,
    );
  }

  static ThemeMode _themeFrom(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static MotionLevel _motionFrom(String? v) => switch (v) {
        'reduced' => MotionLevel.reduced,
        'off' => MotionLevel.off,
        _ => MotionLevel.full,
      };

  static String themeKey(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static String motionKey(MotionLevel m) => switch (m) {
        MotionLevel.full => 'full',
        MotionLevel.reduced => 'reduced',
        MotionLevel.off => 'off',
      };

  void _save(Settings s) {
    prefs.setString('${_kPrefix}baseUrl', s.baseUrl);
    prefs.setString('${_kPrefix}secret', s.secret);
    prefs.setBool('${_kPrefix}demoMode', s.demoMode);
    prefs.setString('${_kPrefix}theme', themeKey(s.themeMode));
    prefs.setString('${_kPrefix}motion', motionKey(s.motion));
    prefs.setString('${_kPrefix}sort', s.sortMode);
    prefs.setString('${_kPrefix}nodeSort', s.nodeSortMode);
    prefs.setString('${_kPrefix}layout', s.proxyLayout);
    prefs.setBool('${_kPrefix}hideTimeout', s.hideTimeout);
    prefs.setString('${_kPrefix}density', s.density);
    prefs.setString('${_kPrefix}connView', s.connView);
    prefs.setBool('${_kPrefix}w.nodeName', s.showNodeName);
    prefs.setBool('${_kPrefix}w.delay', s.showDelay);
    prefs.setBool('${_kPrefix}w.traffic', s.showTraffic);
    prefs.setBool('${_kPrefix}w.memory', s.showMemory);
    prefs.setBool('${_kPrefix}w.updatedAt', s.showUpdatedAt);
    prefs.setInt('${_kPrefix}accent', s.accentColor);
    prefs.setInt('${_kPrefix}proxyCols', s.proxyColumns);
    prefs.setString('${_kPrefix}cardSize', s.proxyCardSize);
    prefs.setDouble('${_kPrefix}cardHeight', s.cardHeight);
    prefs.setDouble('${_kPrefix}logoSize', s.proxyLogoSize);
    prefs.setBool('${_kPrefix}groupByProvider', s.groupByProvider);
    prefs.setString('${_kPrefix}delayUrl', s.delayTestUrl);
    prefs.setString('${_kPrefix}delayMode', s.delayTestMode);
    prefs.setBool('${_kPrefix}wallpaper', s.useWallpaper);
    prefs.setDouble('${_kPrefix}navRadius', s.navRadius);
    prefs.setDouble('${_kPrefix}navOpacity', s.navOpacity);
    prefs.setBool('${_kPrefix}navGlass', s.navGlass);
    prefs.setString('${_kPrefix}bg', s.backgroundImage);
    prefs.setDouble('${_kPrefix}bgDim', s.backgroundDim);
    prefs.setString('${_kPrefix}chartStyle', s.chartStyle);
    prefs.setInt('${_kPrefix}chartUp', s.chartUpColor);
    prefs.setInt('${_kPrefix}chartDown', s.chartDownColor);
    prefs.setDouble('${_kPrefix}surfOpacity', s.surfaceOpacity);
    prefs.setBool('${_kPrefix}sheetGlass', s.sheetGlass);
    prefs.setDouble('${_kPrefix}sheetBlur', s.sheetBlur);
    prefs.setDouble('${_kPrefix}bgBlur', s.bgBlur);
    prefs.setString('${_kPrefix}font', s.fontFamily);
    prefs.setBool('${_kPrefix}haptics', s.haptics);
    prefs.setBool('${_kPrefix}showGlobal', s.showGlobalGroup);
    prefs.setBool('${_kPrefix}perfOverlay', s.showPerfOverlay);
    prefs.setString('${_kPrefix}pageTone', s.pageTone);
    prefs.setDouble('${_kPrefix}fontScale', s.fontScale);
    prefs.setString('${_kPrefix}language', s.language);
    prefs.setDouble('${_kPrefix}titleScale', s.titleScale);
    prefs.setInt('${_kPrefix}toneColor', s.toneColor);
    prefs.setString('${_kPrefix}backends',
        jsonEncode(s.backends.map((e) => e.toJson()).toList()));
    prefs.setString('${_kPrefix}activeBackend', s.activeBackendId);
    prefs.setDouble('${_kPrefix}cardRadius', s.cardRadius);
    prefs.setDouble('${_kPrefix}nodeRadius', s.nodeRadius);
    prefs.setDouble('${_kPrefix}nodeFont', s.nodeFontSize);
    prefs.setDouble('${_kPrefix}nodeGap', s.nodeGap);
    prefs.setDouble('${_kPrefix}nodePadV', s.nodePadV);
  }

  void addBackend(Backend b) {
    final list = [...state.backends, b];
    patch((x) => x.copyWith(
          backends: list,
          activeBackendId: x.activeBackendId.isEmpty ? b.id : x.activeBackendId,
        ));
  }

  void updateBackend(Backend b) {
    final list = [
      for (final e in state.backends) if (e.id == b.id) b else e,
    ];
    patch((x) => x.copyWith(backends: list));
  }

  void removeBackend(String id) {
    final list = state.backends.where((e) => e.id != id).toList();
    patch((x) => x.copyWith(
          backends: list,
          activeBackendId: x.activeBackendId == id
              ? (list.isEmpty ? '' : list.first.id)
              : x.activeBackendId,
        ));
  }

  void setActiveBackend(String id) {
    patch((x) => x.copyWith(activeBackendId: id));
  }

  void patch(Settings Function(Settings) fn) {
    final next = fn(state);
    state = next;
    _save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

// ---------------------------------------------------------------- 后端

final demoProvider = Provider<DemoBackend>((ref) {
  final d = DemoBackend();
  ref.onDispose(d.dispose);
  return d;
});

final clientProvider = Provider<MihomoClient?>((ref) {
  final s = ref.watch(settingsProvider);
  if (s.demoMode) return null;
  final b = s.activeBackend;
  final url = (b?.baseUrl ?? s.baseUrl).trim();
  if (url.isEmpty) return null;
  return MihomoClient(baseUrl: url, secret: b?.secret ?? s.secret);
});

/// 页面滑动中标记：滑动期间不发起新的网络轮询，避免和动画抢帧
class UiBusyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) {
    if (state != v) state = v;
  }
}

final uiBusyProvider =
    NotifierProvider<UiBusyNotifier, bool>(UiBusyNotifier.new);

/// 最近一次拉取代理列表的错误（用于界面提示）
class ClientErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? v) => state = v;
}

final clientErrorProvider =
    NotifierProvider<ClientErrorNotifier, String?>(ClientErrorNotifier.new);

/// 轮询代理列表（演示模式直接反射内存状态）
final proxiesProvider = StreamProvider<Map<String, MihomoProxy>>((ref) async* {
  final settings = ref.watch(settingsProvider);
  final client = ref.watch(clientProvider);
  final demo = ref.watch(demoProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  String? lastSignature;
  Map<String, MihomoProxy>? lastGood;

  while (!disposed) {
    try {
      if (settings.demoMode) {
        yield Map<String, MihomoProxy>.unmodifiable(demo.proxies);
      } else if (client != null) {
        // 偶发失败重试两次，避免一次抖动就整页空白
        var data = <String, MihomoProxy>{};
        Object? lastErr;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            data = await client.proxies();
            lastErr = null;
            break;
          } catch (e) {
            lastErr = e;
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        }
        if (lastErr != null) throw lastErr;
        ref.read(clientErrorProvider.notifier).set(null);

        // 有些内核的 /proxies 只返回分组，节点在 /providers/proxies 里
        final needProviders = data.values.any((g) =>
            g.isGroup && g.all.any((n) => !data.containsKey(n)));
        Map<String, MihomoProxy> result = data;
        if (needProviders) {
          try {
            final provs = await client.providers();
            final merged = <String, MihomoProxy>{...data};
            for (final p in provs.values) {
              for (final n in p.proxies) {
                merged.putIfAbsent(n.name, () => n);
              }
            }
            result = merged;
          } catch (_) {
            result = data;
          }
        }

        // 内容没变化就不推送，避免定时器把整页重绘
        final sig = '${result.length}|'
            '${result.values.where((e) => e.isGroup).map((e) => e.now).join(",")}|'
            '${result.values.fold<int>(0, (a, e) => a + (e.delay ?? 0))}';
        final hasGroup = result.values.any((p) => p.isGroup);
        final lastHadGroup = lastGood?.values.any((p) => p.isGroup) ?? false;
        if (result.isNotEmpty && hasGroup) lastGood = result;
        // 内核配置重载期间会返回「有节点但没有分组」的降级数据，别覆盖
        if (!hasGroup && lastHadGroup && lastGood != null) {
          result = lastGood!;
        }
        // 内核刚启动/重连时可能返回空表，别把已有列表清空
        if (result.isEmpty && lastGood != null) {
          if (sig != lastSignature) {
            lastSignature = sig;
            yield lastGood!;
          }
        } else if (sig != lastSignature) {
          lastSignature = sig;
          yield result;
        }
      } else {
        yield const {};
      }
    } catch (e) {
      ref.read(clientErrorProvider.notifier).set(describeError(e));
      // 拉取失败时继续显示上一次的数据，不要清空整页
      if (lastGood != null) {
        yield lastGood!;
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      yield const {};
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

/// 手动测速结果覆盖（真实模式下 /proxies 刷新前先显示）
class DelayOverridesNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void set(String name, int delay) {
    state = {...state, name: delay};
  }

  /// 清除某个节点的测速结果（切换节点后让它回到内核值）
  void remove(String name) {
    if (!state.containsKey(name)) return;
    state = {...state}..remove(name);
  }
}

final delayOverridesProvider =
    NotifierProvider<DelayOverridesNotifier, Map<String, int>>(
  DelayOverridesNotifier.new,
);

/// 正在测速的节点集合
class TestingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String name) => state = {...state, name};
  void remove(String name) => state = {...state}..remove(name);
  void clear() => state = const {};
}

final testingProvider = NotifierProvider<TestingNotifier, Set<String>>(
  TestingNotifier.new,
);

// ---------------------------------------------------------------- 实时数据

/// 断线自动重连：直到 provider 被销毁为止
/// 最近一次收到实时数据的时刻（用于看门狗判断是否静默）
DateTime lastLiveDataAt = DateTime.fromMillisecondsSinceEpoch(0);

Stream<T> _keepAlive<T>(Stream<T> Function() open, {Duration? idle}) async* {
  final limit = idle ?? const Duration(seconds: 8);
  while (true) {
    try {
      // 超过 idle 没数据就主动断开重连，避免半死连接一直挂着
      yield* open().map((e) {
        lastLiveDataAt = DateTime.now();
        return e;
      }).timeout(
        limit,
        onTimeout: (sink) => sink.close(),
      );
    } catch (_) {
      // 忽略，等下一轮重连
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

final trafficProvider = StreamProvider<TrafficSample>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).trafficStream;
  final client = ref.watch(clientProvider);
  if (client == null) return const Stream.empty();
  // /traffic 每帧自带累计流量，直接用它做总量，少依赖一条连接流
  return _keepAlive(client.traffic).map((s) {
    if (s.upTotal != null && s.downTotal != null) {
      ref.read(coreTotalsProvider.notifier).set(s.upTotal!, s.downTotal!);
    }
    return s;
  });
});

final memoryProvider = StreamProvider<MemorySample>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).memoryStream;
  final client = ref.watch(clientProvider);
  if (client == null) return const Stream.empty();
  return _keepAlive(client.memory);
});

/// 最近 60 个流量采样，用于仪表盘曲线
class TrafficHistoryNotifier extends Notifier<List<TrafficPoint>> {
  @override
  List<TrafficPoint> build() {
    ref.listen(trafficProvider, (prev, next) {
      next.whenData((s) {
        final list = [...state, TrafficPoint(s.up.toDouble(), s.down.toDouble())];
        if (list.length > 60) list.removeRange(0, list.length - 60);
        state = list;
        ref.read(trafficTotalProvider.notifier).add(s.up.toDouble(), s.down.toDouble());
      });
    });
    return const [];
  }
}

/// 本次会话累计流量（按采样累加，约等于 1 秒一次）
class TrafficTotalNotifier extends Notifier<({double up, double down})> {
  @override
  ({double up, double down}) build() => (up: 0, down: 0);

  void add(double up, double down) {
    state = (up: state.up + up, down: state.down + down);
  }

  void reset() => state = (up: 0, down: 0);
}

final trafficTotalProvider =
    NotifierProvider<TrafficTotalNotifier, ({double up, double down})>(
  TrafficTotalNotifier.new,
);

final trafficHistoryProvider =
    NotifierProvider<TrafficHistoryNotifier, List<TrafficPoint>>(
  TrafficHistoryNotifier.new,
);

/// 本机大致位置（来自 ipinfo 的 loc 字段）
class LocalGeoNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() => null;

  void set(GeoPoint? v) => state = v;
}

final localGeoProvider =
    NotifierProvider<LocalGeoNotifier, GeoPoint?>(LocalGeoNotifier.new);

/// 内核开机以来的累计流量（来自 /connections 推送）
class CoreTotalsNotifier extends Notifier<({int up, int down})> {
  @override
  ({int up, int down}) build() => (up: 0, down: 0);

  void set(int up, int down) => state = (up: up, down: down);
}

final coreTotalsProvider =
    NotifierProvider<CoreTotalsNotifier, ({int up, int down})>(
  CoreTotalsNotifier.new,
);

final connectionsProvider = StreamProvider<List<ConnectionInfo>>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).connectionsStream;
  final client = ref.watch(clientProvider);
  if (client == null) return const Stream.empty();
  return client.connections(
    onTotals: (up, down) => ref.read(coreTotalsProvider.notifier).set(up, down),
  ).map((list) {
    // 最新建立的连接排最前，方便看
    final sorted = [...list]..sort((a, b) => b.start.compareTo(a.start));
    return sorted;
  });
});

final rulesProvider = FutureProvider<List<RuleEntry>>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).rules();
  final client = ref.watch(clientProvider);
  if (client == null) return const [];
  try {
    return await client.rules();
  } catch (_) {
    return const [];
  }
});

final versionProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return 'v1.19.2 (demo)';
  final client = ref.watch(clientProvider);
  if (client == null) return '--';
  try {
    return await client.version();
  } catch (_) {
    return '离线';
  }
});

// ---------------------------------------------------------------- 日志

class LogsState {
  const LogsState({this.lines = const [], this.paused = false});

  final List<LogLine> lines;
  final bool paused;

  LogsState copyWith({List<LogLine>? lines, bool? paused}) =>
      LogsState(lines: lines ?? this.lines, paused: paused ?? this.paused);
}

class LogLevelNotifier extends Notifier<String> {
  @override
  String build() => 'info';

  void set(String level) => state = level;
}

final logLevelProvider = NotifierProvider<LogLevelNotifier, String>(
  LogLevelNotifier.new,
);

class LogsNotifier extends Notifier<LogsState> {
  StreamSubscription<LogLine>? _sub;

  @override
  LogsState build() {
    ref.onDispose(() => _sub?.cancel());
    final settings = ref.watch(settingsProvider);
    final level = ref.watch(logLevelProvider);
    _sub?.cancel();

    final Stream<LogLine> stream;
    if (settings.demoMode) {
      stream = ref.watch(demoProvider).logsStream;
    } else {
      final client = ref.watch(clientProvider);
      stream = client?.logs(level: level) ?? const Stream.empty();
    }

    _sub = stream.listen((line) {
      if (state.paused) return;
      final list = [...state.lines, line];
      if (list.length > 500) list.removeRange(0, list.length - 500);
      state = state.copyWith(lines: list);
    });
    return const LogsState();
  }

  void togglePause() => state = state.copyWith(paused: !state.paused);

  void clear() => state = const LogsState(paused: false);
}

final logsProvider = NotifierProvider<LogsNotifier, LogsState>(
  LogsNotifier.new,
);

// ---------------------------------------------------------------- 选择的分组

class SelectedGroupNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? group) => state = group;
}

final selectedGroupProvider =
    NotifierProvider<SelectedGroupNotifier, String?>(SelectedGroupNotifier.new);

// ---------------------------------------------------------------- 出站模式

class OutboundModeNotifier extends Notifier<String> {
  @override
  String build() => prefs.getString('${_kPrefix}mode') ?? 'rule';

  Future<void> set(String mode) async {
    state = mode;
    prefs.setString('${_kPrefix}mode', mode);
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) return;
    try {
      await ref.read(clientProvider)?.setMode(mode);
    } catch (_) {}
  }
}

final outboundModeProvider = NotifierProvider<OutboundModeNotifier, String>(
  OutboundModeNotifier.new,
);

// ---------------------------------------------------------------- 仪表盘卡片

/// 仪表盘卡片 id（顺序即展示顺序，可增删）
const kDashboardCards = <String>[
  'networkSpeed',
  'networkInfo',
  'outboundMode',
  'latency',
  'connectionStats',
  'memoryInfo',
];

const kDashboardCardLabels = <String, String>{
  'networkSpeed': '实时速度',
  'networkInfo': '网络信息',
  'outboundMode': '出站模式',
  'latency': '延时',
  'connectionStats': '连接统计',
  'memoryInfo': '内核占用',
};

class DashboardCardsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final raw = prefs.getString('${_kPrefix}dash.cards');
    if (raw == null || raw.isEmpty) return kDashboardCards;
    final list = raw.split(',').where((e) => e.isNotEmpty).toList();
    return list.isEmpty ? kDashboardCards : list;
  }

  void _save(List<String> list) {
    state = list;
    prefs.setString('${_kPrefix}dash.cards', list.join(','));
  }

  void toggle(String id) {
    final list = [...state];
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    _save(list);
  }

  void move(String id, int delta) {
    final list = [...state];
    final i = list.indexOf(id);
    if (i < 0) return;
    final j = (i + delta).clamp(0, list.length - 1);
    if (i == j) return;
    list.removeAt(i);
    list.insert(j, id);
    _save(list);
  }

  void reset() => _save(kDashboardCards);
}

final dashboardCardsProvider =
    NotifierProvider<DashboardCardsNotifier, List<String>>(
  DashboardCardsNotifier.new,
);


/// 最近 40 个内存采样，用于心率式曲线
class MemoryHistoryNotifier extends Notifier<List<double>> {
  @override
  List<double> build() {
    ref.listen(memoryProvider, (prev, next) {
      next.whenData((m) {
        final list = [...state, m.inuse.toDouble()];
        if (list.length > 40) list.removeRange(0, list.length - 40);
        state = list;
      });
    });
    return const [];
  }
}

final memoryHistoryProvider =
    NotifierProvider<MemoryHistoryNotifier, List<double>>(
  MemoryHistoryNotifier.new,
);

/// 供应商列表（机场）：演示模式返回模拟数据
final providersProvider = FutureProvider<Map<String, ProviderInfo>>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).providers();
  final client = ref.watch(clientProvider);
  if (client == null) return const {};
  try {
    final data = await client.providers();
    ref.read(clientErrorProvider.notifier).set(null);
    return data;
  } catch (e) {
    ref.read(clientErrorProvider.notifier).set(describeError(e));
    return const {};
  }
});


/// 规则集供应商
final ruleProvidersProvider =
    FutureProvider<Map<String, RuleProviderInfo>>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (settings.demoMode) return ref.watch(demoProvider).ruleProviders();
  final client = ref.watch(clientProvider);
  if (client == null) return const {};
  try {
    final data = await client.ruleProviders();
    ref.read(clientErrorProvider.notifier).set(null);
    return data;
  } catch (e) {
    ref.read(clientErrorProvider.notifier).set(describeError(e));
    return const {};
  }
});


/// 本地标记为「停用」的规则（mihomo 无运行时停用单条规则的接口）
class DisabledRulesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final raw = prefs.getString('glimpse.rules.disabled');
    if (raw == null || raw.isEmpty) return const {};
    return raw.split('\n').where((e) => e.isNotEmpty).toSet();
  }

  void toggle(String key) {
    final next = {...state};
    next.contains(key) ? next.remove(key) : next.add(key);
    state = next;
    prefs.setString('glimpse.rules.disabled', next.join('\n'));
  }

  void clear() {
    state = const {};
    prefs.remove('glimpse.rules.disabled');
  }
}

final disabledRulesProvider =
    NotifierProvider<DisabledRulesNotifier, Set<String>>(
  DisabledRulesNotifier.new,
);


/// 规则启停的本地乐观状态（index -> disabled），成功后由内核数据覆盖
class RuleOverridesNotifier extends Notifier<Map<int, bool>> {
  @override
  Map<int, bool> build() => const {};

  void set(int index, bool disabled) {
    state = {...state, index: disabled};
  }

  void clear() => state = const {};
}

final ruleOverridesProvider =
    NotifierProvider<RuleOverridesNotifier, Map<int, bool>>(
  RuleOverridesNotifier.new,
);


/// 代理页顶部 tab：0 = 代理组，1 = 供应商
class ProxyTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int v) => state = v;
}

final proxyTabProvider =
    NotifierProvider<ProxyTabNotifier, int>(ProxyTabNotifier.new);

/// 当前打开的分组名（null 表示在分组列表）
class ProxyOpenedNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? v) => state = v;
}

final proxyOpenedProvider =
    NotifierProvider<ProxyOpenedNotifier, String?>(ProxyOpenedNotifier.new);


/// 仪表盘编辑模式（长按进入，抖动删除 / 排序）
class DashboardEditNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
  void toggle() => state = !state;
}

final dashboardEditProvider =
    NotifierProvider<DashboardEditNotifier, bool>(DashboardEditNotifier.new);


/// App 自身版本号（与 pubspec 同步）
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version.isEmpty ? '—' : info.version;
  } catch (_) {
    return '—';
  }
});


/// 按规则聚合的连接流量（上下行合计），key = "type · payload"
final ruleTrafficProvider = Provider<Map<String, int>>((ref) {
  final conns = ref.watch(connectionsProvider).value ?? const [];
  final out = <String, int>{};
  for (final c in conns) {
    final key = '${c.rule} · ${c.rulePayload}';
    out[key] = (out[key] ?? 0) + c.upload + c.download;
  }
  return out;
});



/// 用户在「自动选择型分组」（url-test/fallback）里手动指定过节点的组名
class ManualGroupsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final raw = prefs.getStringList('glimpse.manualGroups') ?? const [];
    return raw.toSet();
  }

  void mark(String group) {
    if (state.contains(group)) return;
    final next = {...state, group};
    state = next;
    prefs.setStringList('glimpse.manualGroups', next.toList());
  }

  void clear(String group) {
    if (!state.contains(group)) return;
    final next = {...state}..remove(group);
    state = next;
    prefs.setStringList('glimpse.manualGroups', next.toList());
  }
}

final manualGroupsProvider =
    NotifierProvider<ManualGroupsNotifier, Set<String>>(
        ManualGroupsNotifier.new);


/// 本地记录「刚手动选择的节点」，用于立即反映到分组卡（内核轮询有延迟）
class NowOverrideNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void set(String group, String node) {
    state = {...state, group: node};
  }

  /// 内核数据追上了就清掉本地覆盖
  void sync(String group, String? now) {
    final cur = state[group];
    if (cur == null) return;
    if (cur == now) {
      final next = {...state}..remove(group);
      state = next;
    }
  }
}

final nowOverrideProvider =
    NotifierProvider<NowOverrideNotifier, Map<String, String>>(
  NowOverrideNotifier.new,
);

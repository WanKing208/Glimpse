import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/jelly.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/providers.dart';
import '../widgets/common.dart';
import 'diagnostics_dialog.dart';
import '../widgets/color_wheel.dart';
import '../widgets/prism.dart';

/// 设置分区：点开是一张悬浮弹窗
class _Section {
  const _Section({
    required this.id,
    required this.title,
    required this.icon,
    required this.keywords,
    required this.summary,
    required this.content,
  });

  final String id;
  final String title;
  final IconData icon;
  final String keywords;
  final String summary;
  final List<Widget> Function(BuildContext, WidgetRef, Settings) content;
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final sections = <_Section>[
      _Section(
        id: 'theme',
        title: tr('主题'),
        icon: Icons.palette_outlined,
        keywords: '主题 外观 深色 浅色 强调色 壁纸 底栏 弧度 透明 玻璃 背景 图片 图表',
        summary: [
          switch (settings.themeMode) {
            ThemeMode.system => '跟随系统',
            ThemeMode.light => '浅色',
            ThemeMode.dark => '深色',
          },
          settings.useWallpaper ? '壁纸取色' : '手动配色',
          settings.backgroundImage.isEmpty ? '无背景' : '自定义背景',
        ].join(' · '),
        content: (ctx, r, st) => [
          _Block(title: tr('外观'), children: [
            _ChoiceRow<ThemeMode>(
              title: tr('外观模式'),
              value: st.themeMode,
              options: const {
                ThemeMode.system: '跟随系统',
                ThemeMode.light: '浅色',
                ThemeMode.dark: '深色',
              },
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(themeMode: v)),
            ),
            _SwitchRow(
              title: tr('壁纸取色'),
              value: st.useWallpaper,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(useWallpaper: v)),
            ),
          ]),
          _Block(title: tr('配色'), children: [
            _AccentRow(
              value: st.accentColor,
              disabled: st.useWallpaper,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(accentColor: v)),
            ),
            const _ToneRow(),
          ]),
          _Block(title: tr('圆角'), children: [
            _SliderRow(
              title: tr('分组圆角'),
              value: st.cardRadius,
              min: 6,
              max: 28,
              suffix: 'dp',
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(cardRadius: v)),
            ),
            _SliderRow(
              title: tr('节点圆角'),
              value: st.nodeRadius,
              min: 4,
              max: 24,
              suffix: 'dp',
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(nodeRadius: v)),
            ),
            _SliderRow(
              title: tr('分组 logo'),
              value: st.proxyLogoSize,
              min: 20,
              max: 46,
              suffix: 'dp',
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(proxyLogoSize: v)),
            ),
          ]),
          _Block(title: '节点外观', children: [
            _SliderRow(
              title: '字号',
              value: st.nodeFontSize,
              min: 10,
              max: 15,
              suffix: '',
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(nodeFontSize: v)),
            ),
          ]),
          _Block(title: tr('界面'), children: [
            _SliderRow(
              title: tr('不透明度'),
              value: st.surfaceOpacity,
              min: 0.45,
              max: 1.0,
              suffix: '',
              percent: true,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(surfaceOpacity: v)),
            ),
            _SwitchRow(
              title: '悬浮窗磨砂',
              value: st.sheetGlass,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(sheetGlass: v)),
            ),
            if (st.sheetGlass)
              _SliderRow(
                title: '磨砂强度',
                value: st.sheetBlur,
                min: 4,
                max: 32,
                suffix: '',
                onChanged: (v) =>
                    notifier.patch((x) => x.copyWith(sheetBlur: v)),
              ),
          ]),
          _Block(title: tr('底栏'), children: [
            _SliderRow(
              title: tr('圆角'),
              value: st.navRadius,
              min: 0,
              max: 34,
              suffix: 'dp',
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(navRadius: v)),
            ),
            _SliderRow(
              title: tr('不透明度'),
              value: st.navOpacity,
              min: 0.35,
              max: 1.0,
              suffix: '',
              percent: true,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(navOpacity: v)),
            ),
            _SwitchRow(
              title: tr('毛玻璃效果'),
              value: st.navGlass,
              onChanged: (v) => notifier.patch((x) => x.copyWith(navGlass: v)),
            ),
          ]),
          _Block(title: tr('背景'), children: [
            _BackgroundRow(
              value: st.backgroundImage,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(backgroundImage: v)),
            ),
            _SliderRow(
              title: tr('背景模糊'),
              value: st.bgBlur,
              min: 0,
              max: 30,
              suffix: '',
              onChanged: (v) => notifier.patch((x) => x.copyWith(bgBlur: v)),
            ),
            _SliderRow(
              title: tr('背景压暗'),
              value: st.backgroundDim,
              min: 0,
              max: 0.8,
              suffix: '',
              percent: true,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(backgroundDim: v)),
            ),
          ]),
          _Block(title: tr('流量图'), children: [
            _ChoiceRow<String>(
              title: tr('图形样式'),
              value: st.chartStyle,
              options: const {
                'dot': '点阵',
                'bar': '块状',
                'line': '折线',
                'smooth': '平滑曲线',
                'area': '渐变面积',
                'step': '阶梯线',
                'ecg': '心电尖峰',
              },
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(chartStyle: v)),
            ),
            _ColorRow(
              title: tr('上行颜色'),
              value: st.chartUpColor,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(chartUpColor: v)),
            ),
            _ColorRow(
              title: tr('下行颜色'),
              value: st.chartDownColor,
              onChanged: (v) =>
                  notifier.patch((x) => x.copyWith(chartDownColor: v)),
            ),
          ]),
        ],
      ),
      _Section(
        id: 'general',
        title: tr('通用'),
        icon: Icons.tune_rounded,
        keywords: '动画 动效 精简 关闭',
        summary: settings.motion == MotionLevel.full
            ? '完整动效'
            : (settings.motion == MotionLevel.reduced ? '精简动效' : '关闭动效'),
        content: (ctx, r, st) => [
          _ChoiceRow<MotionLevel>(
            title: tr('动画强度'),
            value: st.motion,
            options: const {
              MotionLevel.full: '完整',
              MotionLevel.reduced: '精简',
              MotionLevel.off: '关闭',
            },
            onChanged: (v) => notifier.patch((x) => x.copyWith(motion: v)),
          ),
          _Gap(),
          _ChoiceRow<String>(
            title: tr('语言'),
            value: st.language,
            options: const {'zh': '中文', 'en': 'English'},
            onChanged: (v) => notifier.patch((x) => x.copyWith(language: v)),
          ),
          _ChoiceRow<String>(
            title: tr('字体'),
            value: st.fontFamily,
            options: const {
              'system': '系统默认',
              'serif': '衬线',
              'mono': '等宽',
            },
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(fontFamily: v)),
          ),
          _SliderRow(
            title: tr('正文字号'),
            value: st.fontScale,
            min: 0.85,
            max: 1.8,
            suffix: 'x',
            onChanged: (v) => notifier.patch((x) => x.copyWith(fontScale: v)),
          ),
          _SliderRow(
            title: tr('标题字号'),
            value: st.titleScale,
            min: 0.85,
            max: 1.8,
            suffix: 'x',
            onChanged: (v) => notifier.patch((x) => x.copyWith(titleScale: v)),
          ),
          _Gap(),
          _SwitchRow(
            title: tr('震动反馈'),
            value: st.haptics,
            onChanged: (v) => notifier.patch((x) => x.copyWith(haptics: v)),
          ),
        ],
      ),
      _Section(
        id: 'connection',
        title: tr('连接'),
        icon: Icons.link_outlined,
        keywords: '控制器 地址 密钥 secret 演示 demo 测试',
        summary: settings.demoMode
            ? (kShots ? settings.baseUrl : '演示模式 · ${settings.baseUrl}')
            : settings.baseUrl,
        content: (ctx, r, st) => [
          const _BackendList(),
          _Gap(),
          _Row(
            title: tr('测试连接'),
            onTap: () => _testConnection(context, ref),
          ),
        ],
      ),
      _Section(
        id: 'proxy',
        title: tr('代理设置'),
        icon: Icons.swap_vert_circle_outlined,
        keywords: '布局 列 列表 网格 卡片 尺寸 排序 超时',
        summary: [
          switch (settings.proxyColumns) {
            1 => '列表',
            2 => '两列',
            _ => '三列',
          },
          switch (settings.proxyCardSize) {
            'small' => '小卡片',
            'large' => '大卡片',
            _ => '中卡片',
          },
          settings.hideTimeout ? '隐藏超时' : '显示全部',
        ].join(' · '),
        content: (ctx, r, st) => [
          _ChoiceRow<int>(
            title: tr('分组布局'),
            value: st.proxyColumns,
            options: const {1: '列表', 2: '两列', 3: '三列'},
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(proxyColumns: v)),
          ),
          _Gap(),
          _SliderRow(
            title: tr('分组 logo'),
            value: st.proxyLogoSize,
            min: 20,
            max: 46,
            suffix: 'dp',
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(proxyLogoSize: v)),
          ),
          _SliderRow(
            title: tr('卡片高度'),
            value: st.cardHeight,
            min: 0.7,
            max: 1.8,
            suffix: '',
            onChanged: (v) => notifier.patch((x) => x.copyWith(cardHeight: v)),
          ),
          _Gap(),
          _ChoiceRow<String>(
            title: tr('代理组排序'),
            value: st.sortMode,
            options: const {
              'config': '按配置顺序',
              'default': '规则/区域优先',
              'nameAsc': '名称 A→Z',
              'nameDesc': '名称 Z→A',
              'delayAsc': '延时 低→高',
              'delayDesc': '延时 高→低',
            },
            onChanged: (v) => notifier.patch((x) => x.copyWith(sortMode: v)),
          ),
          _Gap(),
          _ChoiceRow<String>(
            title: tr('节点排序'),
            value: st.nodeSortMode,
            options: const {
              'config': '按配置顺序',
              'default': '规则/区域优先',
              'nameAsc': '名称 A→Z',
              'nameDesc': '名称 Z→A',
              'delayAsc': '延时 低→高',
              'delayDesc': '延时 高→低',
            },
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(nodeSortMode: v)),
          ),
          _Gap(),
          _ChoiceRow<String>(
            title: tr('测速方式'),
            value: st.delayTestMode,
            options: const {
              'app': '由 App 测（用下面地址）',
              'config': '交给内核按配置测',
            },
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(delayTestMode: v)),
          ),
          if (st.delayTestMode == 'app')
            _Row(
              title: tr('测速地址'),
              subtitle: st.delayTestUrl,
              onTap: () => _editText(
                ctx,
                title: tr('测速地址'),
                hint: 'https://www.gstatic.com/generate_204',
                initial: st.delayTestUrl,
                onSave: (v) =>
                    notifier.patch((x) => x.copyWith(delayTestUrl: v.trim())),
              ),
            ),
          _Gap(),
          _SwitchRow(
            title: tr('显示 GLOBAL 分组'),
            value: st.showGlobalGroup,
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(showGlobalGroup: v)),
          ),
          _Gap(),
          _SwitchRow(
            title: tr('节点按机场分组'),
            value: st.groupByProvider,
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(groupByProvider: v)),
          ),
          _Gap(),
          _SwitchRow(
            title: 'IPv6 测试',
            subtitle: '测速时用 IPv6 地址探测节点',
            value: st.ipv6Test,
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(ipv6Test: v)),
          ),
          _Gap(),
          _SwitchRow(
            title: tr('隐藏不可用节点'),
            value: st.hideTimeout,
            onChanged: (v) =>
                notifier.patch((x) => x.copyWith(hideTimeout: v)),
          ),
        ],
      ),
      _Section(
        id: 'kernel',
        title: tr('内核'),
        icon: Icons.dns_outlined,
        keywords: '内核 重启 重载 配置 dns fakeip geo 端口 局域网 lan',
        summary: settings.demoMode && !kShots
            ? '演示模式下不生效'
            : '重启 / 重载 / 清缓存 / 端口',
        content: (ctx, r, st) => [
          const _KernelInfo(),
          _Gap(),
          _ActionRow(
            title: tr('连接诊断'),
            icon: Icons.bug_report_outlined,
            onTap: () => showDiagnostics(context),
          ),
          _Gap(),
          _ActionRow(
            title: tr('重启内核'),
            icon: Icons.restart_alt_rounded,
            danger: true,
            onTap: () => _confirmAction(
              context,
              title: tr('重启内核'),
              message: '内核会短暂中断，确定重启？',
              run: () => ref.read(clientProvider)?.restartCore(),
            ),
          ),
          _Gap(),
          _ActionRow(
            title: tr('重新载入配置'),
            icon: Icons.refresh_rounded,
            onTap: () => _confirmAction(
              context,
              title: tr('重新载入配置'),
              message: '将从配置文件重新加载，运行中的连接会断开。',
              run: () =>
                  ref.read(clientProvider)?.reloadConfigs(force: true),
            ),
          ),
          _Gap(),
          _ActionRow(
            title: tr('清空 DNS 缓存'),
            icon: Icons.cleaning_services_outlined,
            onTap: () => _runAction(
              context,
              () => ref.read(clientProvider)?.flushDnsCache(),
              done: 'DNS 缓存已清空',
            ),
          ),
          _Gap(),
          _ActionRow(
            title: tr('清空 FakeIP'),
            icon: Icons.cleaning_services_outlined,
            onTap: () => _runAction(
              context,
              () => ref.read(clientProvider)?.flushFakeIpCache(),
              done: 'FakeIP 缓存已清空',
            ),
          ),
          _Gap(),
          _ActionRow(
            title: tr('更新 GEO 数据库'),
            icon: Icons.public_rounded,
            onTap: () => _runAction(
              context,
              () => ref.read(clientProvider)?.updateGeo(),
              done: '已触发 GEO 更新',
            ),
          ),
          _Gap(),
          const _KernelPorts(),
        ],
      ),
      _Section(
        id: 'about',
        title: tr('关于'),
        icon: Icons.info_outline_rounded,
        keywords: '版本 内核 应用 id 关于',
        summary: 'mihomo REST + WebSocket',
        content: (ctx, r, st) => [
          _VersionRow(),
          _Gap(),
          _Row(title: tr('内核协议'), subtitle: tr('mihomo REST + WebSocket')),
          _Gap(),
          _Row(title: tr('应用 ID'), subtitle: tr('app.glimpse.glimpse')),
          _Gap(),
        ],
      ),
    ];

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? sections
        : sections
            .where((e) =>
                e.title.toLowerCase().contains(q) ||
                e.keywords.toLowerCase().contains(q))
            .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Text(tr(tr('设置')),
                style: TextStyle(
                    color: s.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9)),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                  color: s.hairline.withValues(alpha: 0.5), width: 0.6),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 17, color: s.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: s.textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '搜索设置项',
                      hintStyle:
                          TextStyle(color: s.textTertiary, fontSize: 13.5),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 16, color: s.textTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: tr('没有匹配的设置项'),
            ),
          for (var i = 0; i < filtered.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JellyEntry(
                index: i,
                staggerMs: 24,
                child: _SectionCard(
                  section: filtered[i],
                  onTap: () => _openSection(context, filtered[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openSection(BuildContext context, _Section section) {
    showJellyDialog<void>(
      context: context,
      maxWidth: 400,
      builder: (_) => Consumer(
        builder: (ctx, r, _) {
          final st = r.watch(settingsProvider);
          return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(section.icon,
                      size: 18, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(section.title,
                        style: TextStyle(
                            color: surfacesOf(ctx).textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  JellyPress(
                    haptic: false,
                    onTap: () => Navigator.of(ctx).pop(),
                    scaleTo: 0.8,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.close_rounded,
                          size: 19, color: surfacesOf(ctx).textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: section.content(ctx, r, st),
                ),
              ),
            ),
          ],
          );
        },
      ),
    );
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (settings.demoMode) {
      messenger.showSnackBar(
          const SnackBar(content: Text('演示模式，无需连接。关闭演示模式并填地址后可测试。')));
      return;
    }
    final client = ref.read(clientProvider);
    if (client == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请先填写控制器地址')));
      return;
    }
    try {
      final v = await client.version();
      messenger.showSnackBar(SnackBar(content: Text('连接成功 · mihomo $v')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(describeError(e)),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required ValueChanged<String> onSave,
  }) async {
    final s = surfacesOf(context);
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: s.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: s.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: s.textTertiary),
            filled: true,
            fillColor: s.block,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          JellyTextButton(label: '取消', onPressed: () => Navigator.of(ctx).pop(), color: s.textSecondary),
          JellyTextButton(label: '保存', onPressed: () => Navigator.of(ctx).pop(ctrl.text)),
        ],
      ),
    );
    if (result != null) onSave(result);
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void>? Function() run,
  }) async {
    final s = surfacesOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: s.textPrimary, fontSize: 16)),
        content: Text(message,
            style: TextStyle(color: s.textSecondary, fontSize: 13)),
        actions: [
          JellyTextButton(label: '取消', onPressed: () => Navigator.of(ctx).pop(false), color: s.textSecondary),
          JellyTextButton(
            label: '确定',
            onPressed: () => Navigator.of(ctx).pop(true),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _runAction(context, run, done: '$title完成');
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void>? Function() action, {
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) {
      messenger.showSnackBar(const SnackBar(content: Text('演示模式：已模拟执行')));
      return;
    }
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('执行失败：$e')));
    }
  }
}

// ---------------------------------------------------------------- 组件

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});

  final _Section section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    return JellyPress(
      onTap: onTap,
      scaleTo: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: cardShadow(context),
        ),
        child: Row(
          children: [
            CookieBadge(
              icon: section.icon,
              size: 38,
              color: cs.primary.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title,
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    section.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: s.textTertiary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: s.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 2);
}

class _KernelInfo extends ConsumerWidget {
  const _KernelInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final version = ref.watch(versionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Icon(Icons.dns_rounded, size: 15, color: s.textSecondary),
          const SizedBox(width: 8),
          Text('内核版本',
              style: TextStyle(color: s.textSecondary, fontSize: 12.5)),
          const Spacer(),
          Text(
            version.maybeWhen(
              data: (v) => v,
              loading: () => '读取中…',
              orElse: () => '未连接',
            ),
            style: TextStyle(
              color: s.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 内核端口与局域网开关：端口从 /configs 读取，未开启显示方框
class _KernelPorts extends ConsumerStatefulWidget {
  const _KernelPorts();

  @override
  ConsumerState<_KernelPorts> createState() => _KernelPortsState();
}

class _KernelPortsState extends ConsumerState<_KernelPorts> {
  static const _portKeys = ['mixed-port', 'socks-port', 'port', 'redir-port', 'tproxy-port'];

  final _ports = <String, int>{
    'mixed-port': 0,
    'socks-port': 0,
    'port': 0,
    'redir-port': 0,
    'tproxy-port': 0,
  };
  bool _allowLan = false;
  String _logLevel = 'info';
  bool _ipv6 = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) {
      setState(() {
        _ports['mixed-port'] = 7890;
        _ports['socks-port'] = 7891;
        _loaded = true;
      });
      return;
    }
    try {
      final cfg = await ref.read(clientProvider)?.configs();
      if (cfg != null && mounted) {
        setState(() {
          for (final k in _portKeys) {
            final v = cfg[k];
            _ports[k] = v is num ? v.toInt() : 0;
          }
          final lan = cfg['allow-lan'];
          if (lan is bool) _allowLan = lan;
          final lv = cfg['log-level'];
          if (lv is String) _logLevel = lv;
          final v6 = cfg['ipv6'];
          if (v6 is bool) _ipv6 = v6;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _apply(Map<String, dynamic> body, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);
    if (settings.demoMode) {
      messenger.showSnackBar(const SnackBar(content: Text('演示模式：已模拟修改')));
      return;
    }
    try {
      await ref.read(clientProvider)?.patchConfigs(body);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('修改失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final enabled = _portKeys.where((k) => (_ports[k] ?? 0) > 0).toList();
    final disabled = _portKeys.where((k) => (_ports[k] ?? 0) <= 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubTitle('运行配置'),
        _SwitchRow(
          title: tr('允许局域网连接'),
          subtitle: _loaded ? '同网段设备可共用代理' : '读取中…',
          value: _allowLan,
          onChanged: (v) {
            setState(() => _allowLan = v);
            _apply({'allow-lan': v}, v ? '已开启局域网' : '已关闭局域网');
          },
        ),
        _SwitchRow(
          title: 'IPv6（内核）',
          value: _ipv6,
          onChanged: (v) {
            setState(() => _ipv6 = v);
            _apply({'ipv6': v}, v ? '已开启 IPv6' : '已关闭 IPv6');
          },
        ),
        _ChoiceRow<String>(
          title: tr('日志等级'),
          value: _logLevel,
          options: const {
            'silent': 'silent',
            'error': 'error',
            'warning': 'warning',
            'info': 'info',
            'debug': 'debug',
          },
          onChanged: (v) {
            setState(() => _logLevel = v);
            _apply({'log-level': v}, '日志等级已改为 $v');
          },
        ),
        const _SubTitle('监听端口'),
        if (enabled.isEmpty && _loaded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text('没有开启的端口',
                style: TextStyle(color: s.textTertiary, fontSize: 11)),
          ),
        for (final key in enabled)
          JellyPress(
            haptic: false,
            onTap: () => _editPort(key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_portLabel(key),
                        style: TextStyle(color: s.textPrimary, fontSize: 13.5)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.block,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_ports[key]}',
                        style: TextStyle(
                            color: s.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ),
                ],
              ),
            ),
          ),
        if (disabled.isNotEmpty) ...[
          const _SubTitle('未开启'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in disabled)
                  JellyPress(
                    haptic: false,
                    onTap: () => _editPort(key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: s.hairline,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Text(
                        _portLabel(key),
                        style:
                            TextStyle(color: s.textTertiary, fontSize: 11.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _portLabel(String key) => switch (key) {
        'mixed-port' => '混合端口',
        'socks-port' => 'SOCKS 端口',
        'port' => 'HTTP 端口',
        'redir-port' => 'REDIR 端口',
        'tproxy-port' => 'TPROXY 端口',
        _ => key,
      };

  Future<void> _editPort(String key) async {
    final s = surfacesOf(context);
    final current = _ports[key] ?? 0;
    final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_portLabel(key),
            style: TextStyle(color: s.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: s.textPrimary),
          decoration: InputDecoration(
            hintText: '留空或 0 表示关闭',
            hintStyle: TextStyle(color: s.textTertiary, fontSize: 12),
            filled: true,
            fillColor: s.block,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          JellyTextButton(label: '取消', onPressed: () => Navigator.of(ctx).pop(), color: s.textSecondary),
          JellyTextButton(label: '保存', onPressed: () => Navigator.of(ctx).pop(ctrl.text)),
        ],
      ),
    );
    if (result == null) return;
    final port = int.tryParse(result.trim()) ?? 0;
    if (port != 0 && (port < 1 || port > 65535)) return;
    setState(() => _ports[key] = port);
    await _apply({key: port}, port == 0 ? '${_portLabel(key)} 已关闭' : '${_portLabel(key)} 已改为 $port');
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
      child: Text(
        text,
        style: TextStyle(
          color: s.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
    this.percent = false,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String suffix;
  final bool percent;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final label =
        percent ? '${(value * 100).round()}%' : '${value.toStringAsFixed(0)}$suffix';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(title,
                style: TextStyle(color: s.textPrimary, fontSize: 13.5)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: s.textTertiary,
                fontSize: 11.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  static const _palette = [
    0xFF007AFF,
    0xFF34C759,
    0xFFFF9500,
    0xFFFF3B30,
    0xFFCB30E0,
    0xFF5AC8FA,
    0xFFFFCC00,
    0xFF8E8E93,
  ];

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(title,
                style: TextStyle(color: s.textPrimary, fontSize: 13.5)),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  JellyPress(
                    haptic: false,
                    onTap: () => onChanged(c),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              value == c ? s.textPrimary : Colors.transparent,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundRow extends StatelessWidget {
  const _BackgroundRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      final path = files.isEmpty ? null : files.first.path;
      if (path != null) onChanged(path);
    } catch (_) {}
  }

  Future<void> _url(BuildContext context) async {
    final s = surfacesOf(context);
    final ctrl =
        TextEditingController(text: value.startsWith('http') ? value : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('在线图片地址',
            style: TextStyle(color: s.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: s.textPrimary),
          decoration: InputDecoration(
            hintText: 'https://…',
            hintStyle: TextStyle(color: s.textTertiary),
            filled: true,
            fillColor: s.block,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          JellyTextButton(label: '取消', onPressed: () => Navigator.of(ctx).pop(), color: s.textSecondary),
          JellyTextButton(label: '确定', onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim())),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('背景图片',
                    style: TextStyle(
                        color: s.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty
                      ? '未设置'
                      : (value.startsWith('http') ? '在线图片' : '本地图片'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: s.textTertiary, fontSize: 10.5),
                ),
              ],
            ),
          ),
          JellyTextButton(label: '本地', onPressed: _pick),
          JellyTextButton(label: '链接', onPressed: () => _url(context)),
          if (value.isNotEmpty)
            JellyPress(
              haptic: false,
              onTap: () => onChanged(''),
              scaleTo: 0.8,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(Icons.close_rounded,
                    size: 16, color: s.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  _Row({required this.title, this.subtitle, this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return JellyPress(
      haptic: false,
      onTap: onTap,
      scaleTo: 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: s.textTertiary, fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: s.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: s.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(color: s.textTertiary, fontSize: 11)),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final label = options[value] ?? '';
    return JellyPress(
      haptic: false,
      scaleTo: 0.99,
      onTap: () async {
        final picked = await showJellyDialog<T>(
          context: context,
          maxWidth: 320,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(title,
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in options.entries)
                          JellyPress(
                            haptic: false,
                            scaleTo: 0.97,
                            onTap: () => Navigator.of(ctx).pop(e.key),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(e.value,
                                        style: TextStyle(
                                            color: s.textPrimary,
                                            fontSize: 14)),
                                  ),
                                  if (e.key == value)
                                    Icon(Icons.check_rounded,
                                        size: 17,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                ],
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
        );
        if (picked != null) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: s.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            Text(label, style: TextStyle(color: s.textTertiary, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: s.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final color = danger ? AppColors.danger : s.textPrimary;
    return JellyPress(
      haptic: false,
      scaleTo: 0.99,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: danger ? AppColors.danger : s.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        style:
                            TextStyle(color: s.textTertiary, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: s.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool disabled;

  static const _palette = [
    0xFF007AFF,
    0xFFCB30E0,
    0xFFFF2D55,
    0xFFFF383C,
    0xFFFF8D28,
    0xFFFFCC00,
    0xFF34C759,
    0xFF8E8E93,
  ];

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('强调色',
                  style: TextStyle(
                      color: s.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _palette)
                    JellyPress(
                      haptic: false,
                      onTap: () => onChanged(c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: value == c
                                ? s.textPrimary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: value == c
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  JellyPress(
                    haptic: false,
                    onTap: () async {
                      final picked =
                          await showColorWheel(context, initial: Color(value));
                      if (picked != null) onChanged(picked.value);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFFFF3B30),
                            Color(0xFFFFCC00),
                            Color(0xFF34C759),
                            Color(0xFF5AC8FA),
                            Color(0xFF007AFF),
                            Color(0xFFCB30E0),
                            Color(0xFFFF3B30),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.colorize_rounded,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}




/// 后台列表：可添加、切换、编辑、删除
class _BackendList extends ConsumerWidget {
  const _BackendList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final active = settings.activeBackend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('后台',
                  style: TextStyle(
                      color: s.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              JellyTextButton(
                label: '添加',
                onPressed: () => _edit(context, ref, null),
              ),
            ],
          ),
        ),
        if (settings.backends.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('还没有后台，点右上角「添加」',
                style: TextStyle(color: s.textTertiary, fontSize: 11)),
          ),
        for (final b in settings.backends)
          JellyPress(
            haptic: false,
            onTap: () => notifier.setActiveBackend(b.id),
            onLongPress: () => _edit(context, ref, b),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    b.id == (active?.id ?? '')
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: b.id == (active?.id ?? '')
                        ? Theme.of(context).colorScheme.primary
                        : s.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: s.textPrimary,
                                fontSize: 13.5,
                                fontWeight: b.id == (active?.id ?? '')
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        Text(b.baseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: s.textTertiary, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  JellyPress(
                    haptic: false,
                    onTap: () => _edit(context, ref, b),
                    scaleTo: 0.8,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.edit_outlined,
                          size: 15, color: s.textTertiary),
                    ),
                  ),
                  JellyPress(
                    haptic: false,
                    onTap: () => notifier.removeBackend(b.id),
                    scaleTo: 0.8,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 15, color: s.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Backend? backend) async {
    final s = surfacesOf(context);
    final nameCtrl = TextEditingController(text: backend?.name ?? '');
    final urlCtrl = TextEditingController(text: backend?.baseUrl ?? 'http://');
    final secretCtrl = TextEditingController(text: backend?.secret ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(backend == null ? '添加后台' : '编辑后台',
            style: TextStyle(color: s.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(s, nameCtrl, '名称', '例如 家里 / 服务器'),
            const SizedBox(height: 8),
            _field(s, urlCtrl, '控制器地址', 'http://192.168.1.5:9090'),
            const SizedBox(height: 8),
            _field(s, secretCtrl, '密钥 Secret', '可留空'),
          ],
        ),
        actions: [
          JellyTextButton(label: '取消', onPressed: () => Navigator.of(ctx).pop(false), color: s.textSecondary),
          JellyTextButton(label: '保存', onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );

    if (saved != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    final notifier = ref.read(settingsProvider.notifier);
    if (backend == null) {
      notifier.addBackend(Backend(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameCtrl.text.trim().isEmpty ? '后台' : nameCtrl.text.trim(),
        baseUrl: url,
        secret: secretCtrl.text.trim(),
      ));
    } else {
      notifier.updateBackend(backend.copyWith(
        name: nameCtrl.text.trim().isEmpty ? backend.name : nameCtrl.text.trim(),
        baseUrl: url,
        secret: secretCtrl.text.trim(),
      ));
    }
  }

  Widget _field(AppSurfaces s, TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      style: TextStyle(color: s.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: s.textTertiary, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: s.textTertiary, fontSize: 12),
        filled: true,
        fillColor: s.block,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}




/// 页面配色：色块选择弹窗
class _ToneRow extends ConsumerWidget {
  const _ToneRow();

  static const _tones = [
    ('ink', Color(0xFF0B0B0F)),
    ('navy', Color(0xFF0A1020)),
    ('forest', Color(0xFF0A1410)),
    ('violet', Color(0xFF120A1E)),
    ('amber', Color(0xFF14100C)),
    ('light', Color(0xFFF2F2F7)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final st = ref.watch(settingsProvider);
    final current = Color(st.pageTone == 'custom'
        ? st.toneColor
        : (_tones.firstWhere((e) => e.$1 == st.pageTone,
                orElse: () => _tones.first)
            .$2)
        .toARGB32());

    return JellyPress(
      haptic: false,
      scaleTo: 0.99,
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Text('页面配色',
                style: TextStyle(
                    color: s.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: current,
                shape: BoxShape.circle,
                border: Border.all(color: s.hairline),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: s.textTertiary),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);

    showJellyDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (ctx, r, _) {
          final st = r.watch(settingsProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('页面配色',
                    style: TextStyle(
                        color: surfacesOf(ctx).textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final (id, color) in _tones)
                      _Swatch(
                        color: color,
                        selected: st.pageTone == id,
                        onTap: () => notifier.patch((x) => x.copyWith(
                              pageTone: id,
                              toneColor: color.toARGB32(),
                            )),
                      ),
                    // 自定义：彩虹球
                    GestureDetector(
                      onTap: () async {
                        final picked = await showColorWheel(
                          ctx,
                          initial: Color(st.toneColor),
                        );
                        if (picked != null) {
                          notifier.patch((x) => x.copyWith(
                                pageTone: 'custom',
                                toneColor: picked.toARGB32(),
                              ));
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFFFF3B30),
                              Color(0xFFFFCC00),
                              Color(0xFF34C759),
                              Color(0xFF5AC8FA),
                              Color(0xFF007AFF),
                              Color(0xFFCB30E0),
                              Color(0xFFFF3B30),
                            ],
                          ),
                          border: Border.all(
                            color: st.pageTone == 'custom'
                                ? surfacesOf(ctx).textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(Icons.colorize_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? s.textPrimary : s.hairline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}


/// 主题设置里的小区块
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
        decoration: BoxDecoration(
          color: s.block.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                title,
                style: TextStyle(
                  color: s.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}


/// 应用版本（读 pubspec 里的 version）
class _VersionRow extends ConsumerWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final v = ref.watch(appVersionProvider).value ?? '…';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('版本',
                style: TextStyle(
                    color: s.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Text(v,
              style: TextStyle(
                  color: s.textTertiary,
                  fontSize: 12.5,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

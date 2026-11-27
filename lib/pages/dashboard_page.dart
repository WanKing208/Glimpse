import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/jelly.dart';
import '../core/geo.dart';
import '../core/net_info.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../widgets/prism.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(dashboardCardsProvider);

    final editing = ref.watch(dashboardEditProvider);

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        children: [
          Consumer(
            builder: (context, ref, _) => PageHeader(
              title: tr('仪表盘'),
              subtitle:
                  ref.watch(settingsProvider).demoMode && !kShots ? '演示数据' : null,
              trailing: [
                JellyPress(
                  haptic: false,
                  onTap: () => showJellyDialog<void>(
                    context: context,
                    maxWidth: 400,
                    builder: (_) => const _DashboardEditor(),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: surfacesOf(context).block,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.tune_rounded,
                        size: 18, color: surfacesOf(context).textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          ..._buildFlow(context, cards),
        ],
          ),
          if (editing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 110,
              child: Center(
                child: JellyPress(
                  onTap: () => ref.read(dashboardEditProvider.notifier).set(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      boxShadow: cardShadow(context),
                    ),
                    child: const Text('完成',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _bigCards = {
    'networkSpeed',
    'networkInfo',
    'outboundMode',
    'latency',
  };

  /// 按顺序流式排版：大卡独占一行，小卡两两成行（可自由上下移动）
  List<Widget> _buildFlow(BuildContext context, List<String> cards) {
    final out = <Widget>[];
    final pending = <String>[];

    void flush() {
      while (pending.isNotEmpty) {
        final pair = pending.take(2).toList();
        pending.removeRange(0, pair.length);
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 122,
              child: Row(
                children: [
                  Expanded(
                      child: _Editable(id: pair[0], child: _card(pair[0]))),
                  if (pair.length > 1) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Editable(id: pair[1], child: _card(pair[1])),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    }

    for (final id in cards.where(kDashboardCards.contains)) {
      if (_bigCards.contains(id)) {
        flush();
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Editable(id: id, child: _card(id)),
          ),
        );
      } else {
        pending.add(id);
      }
    }
    flush();
    return out;
  }

  Widget _card(String id) => switch (id) {
        'networkSpeed' => const _SpeedCard(),
        'networkInfo' => const _NetworkInfoCard(),
        'outboundMode' => const _OutboundModeCard(),
        'latency' => const _LatencyCard(),
        'connectionStats' => const _ConnStatsCard(),
        'memoryInfo' => const _MemoryCoreCard(),
        _ => const SizedBox.shrink(),
      };
}

// ---------------------------------------------------------------- 速度

class _SpeedCard extends ConsumerWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final settings = ref.watch(settingsProvider);
    final traffic = ref.watch(trafficProvider).value;
    final history = ref.watch(trafficHistoryProvider);
    final session = ref.watch(trafficTotalProvider);
    final core = ref.watch(coreTotalsProvider);
    final totalUp = core.up > 0 ? core.up.toDouble() : session.up;
    final totalDown = core.down > 0 ? core.down.toDouble() : session.down;
    final upColor = Color(settings.chartUpColor);
    final downColor = Color(settings.chartDownColor);

    return GlimpseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_vert_rounded,
                            size: 15, color: s.textSecondary),
                        const SizedBox(width: 6),
                        Text('实时流量',
                            style: TextStyle(
                                color: s.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(fmtSpeed((traffic?.up ?? 0) + (traffic?.down ?? 0)),
                        style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniSpeed(
                    color: upColor,
                    icon: Icons.arrow_upward_rounded,
                    value: fmtSpeed(traffic?.up ?? 0),
                  ),
                  const SizedBox(height: 4),
                  _MiniSpeed(
                    color: downColor,
                    icon: Icons.arrow_downward_rounded,
                    value: fmtSpeed(traffic?.down ?? 0),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: TrafficChart(
              points: history,
              maxPoints: 60,
              style: settings.chartStyle,
              upColor: upColor,
              downColor: downColor,
              gridColor: s.hairline,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('总流量',
                  style: TextStyle(color: s.textTertiary, fontSize: 10.5)),
              const SizedBox(width: 10),
              Icon(Icons.arrow_upward_rounded, size: 11, color: upColor),
              Text(' ${fmtBytes(totalUp)}',
                  style: TextStyle(
                      color: s.textSecondary,
                      fontSize: 10.5,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 10),
              Icon(Icons.arrow_downward_rounded, size: 11, color: downColor),
              Text(' ${fmtBytes(totalDown)}',
                  style: TextStyle(
                      color: s.textSecondary,
                      fontSize: 10.5,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSpeed extends StatelessWidget {
  const _MiniSpeed({
    required this.color,
    required this.icon,
    required this.value,
  });

  final Color color;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 流量图：块状 / 圆点频谱 / 折线，上下行各自独立缩放
class TrafficChart extends StatelessWidget {
  const TrafficChart({
    super.key,
    required this.points,
    required this.maxPoints,
    required this.style,
    required this.upColor,
    required this.downColor,
    required this.gridColor,
  });

  final List<TrafficPoint> points;
  final int maxPoints;
  final String style;
  final Color upColor;
  final Color downColor;
  final Color gridColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        points: points,
        maxPoints: maxPoints,
        style: style,
        upColor: upColor,
        downColor: downColor,
        gridColor: gridColor,
      ),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.maxPoints,
    required this.style,
    required this.upColor,
    required this.downColor,
    required this.gridColor,
  });

  final List<TrafficPoint> points;
  final int maxPoints;
  final String style;
  final Color upColor;
  final Color downColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), gridPaint);

    if (points.isEmpty) return;

    // 上下行各自归一化，避免上行被下行压成直线
    double maxUp = 1;
    double maxDown = 1;
    for (final p in points) {
      maxUp = math.max(maxUp, p.up);
      maxDown = math.max(maxDown, p.down);
    }

    final n = points.length;
    final slot = size.width / (maxPoints - 1);
    final startX = size.width - slot * (n - 1);
    final mid = size.height * 0.5;
    final half = size.height * 0.45;

    switch (style) {
      case 'line':
        _line(canvas, startX, slot, maxUp, maxDown, mid, half);
      case 'bar':
        _bars(canvas, startX, slot, maxUp, maxDown, mid, half);
      case 'smooth':
        _smooth(canvas, startX, slot, maxUp, maxDown, mid, half);
      case 'area':
        _area(canvas, startX, slot, maxUp, maxDown, mid, half, size);
      case 'step':
        _step(canvas, startX, slot, maxUp, maxDown, mid, half);
      case 'ecg':
        _ecg(canvas, startX, slot, maxUp, maxDown, mid, half);
      default:
        _dots(canvas, startX, slot, maxUp, maxDown, mid, half);
    }
  }

  /// 点阵频谱：每列一摞小方块，上下对称，越靠近基线越亮
  void _dots(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    final dot = math.max(1.8, math.min(3.6, slot * 0.62));
    final gap = math.max(0.9, dot * 0.30);
    final step = dot + gap;
    final maxRows = math.max(1, (half / step).floor());
    final radius = Radius.circular(dot * 0.26);

    // 靠近基线用亮青，越远越接近主题色
    final downNear = Color.lerp(const Color(0xFF9BE7FF), downColor, 0.25)!;
    final downFar = downColor;
    final upNear = Color.lerp(const Color(0xFFB6F2FF), upColor, 0.30)!;
    final upFar = upColor;

    for (var i = 0; i < points.length; i++) {
      final x = startX + slot * i;
      final dv = points[i].down.clamp(0.0, maxDown) / maxDown;
      final uv = points[i].up.clamp(0.0, maxUp) / maxUp;
      final dRows = (dv * maxRows).ceil();
      final uRows = (uv * maxRows).ceil();

      for (var r = 0; r < dRows; r++) {
        final k = maxRows <= 1 ? 0.0 : r / (maxRows - 1);
        final paint = Paint()..color = Color.lerp(downNear, downFar, k)!;
        final y = mid - dot - r * step;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - dot / 2, y, dot, dot), radius),
          paint,
        );
      }
      for (var r = 0; r < uRows; r++) {
        final k = maxRows <= 1 ? 0.0 : r / (maxRows - 1);
        final paint = Paint()..color = Color.lerp(upNear, upFar, k)!;
        final y = mid + r * step;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - dot / 2, y, dot, dot), radius),
          paint,
        );
      }
    }
  }

  void _bars(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    final gap = math.max(0.6, slot * 0.18);
    final w = math.max(1.2, (slot - gap) / 2);
    final rr = Radius.circular(w / 2);
    final upPaint = Paint()..color = upColor;
    final downPaint = Paint()..color = downColor;

    for (var i = 0; i < points.length; i++) {
      final x = startX + slot * i;
      final dv = points[i].down.clamp(0.0, maxDown) / maxDown;
      final uv = points[i].up.clamp(0.0, maxUp) / maxUp;
      final dh = dv * half;
      final uh = uv * half;
      if (dh > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, mid - dh, w, dh), rr),
          downPaint,
        );
      }
      if (uh > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x + w + gap * 0.4, mid + 2, w, uh), rr),
          upPaint,
        );
      }
    }
  }

  void _line(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    void draw(double Function(TrafficPoint) sel, double maxV, Color color,
        bool below) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = startX + slot * i;
        final v = sel(points[i]).clamp(0.0, maxV) / maxV;
        final y = below ? mid + v * half : mid - v * half;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw((p) => p.down, maxDown, downColor, false);
    draw((p) => p.up, maxUp, upColor, true);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.maxPoints != maxPoints ||
      old.style != style ||
      old.upColor != upColor ||
      old.downColor != downColor;

  // ---------------------------------------------------------- 更多样式

  Path _smoothPath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mx = (p0.dx + p1.dx) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, mx, (p0.dy + p1.dy) / 2);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  List<Offset> _series(double Function(TrafficPoint) sel, double maxV,
      double startX, double slot, double mid, double half, bool below) {
    final out = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = startX + slot * i;
      final v = sel(points[i]).clamp(0.0, maxV) / maxV;
      out.add(Offset(x, below ? mid + v * half : mid - v * half));
    }
    return out;
  }

  void _smooth(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    void draw(double Function(TrafficPoint) sel, double maxV, Color color,
        bool below) {
      final pts = _series(sel, maxV, startX, slot, mid, half, below);
      canvas.drawPath(
        _smoothPath(pts),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw((p) => p.down, maxDown, downColor, false);
    draw((p) => p.up, maxUp, upColor, true);
  }

  void _area(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half, Size areaSize) {
    void draw(double Function(TrafficPoint) sel, double maxV, Color color,
        bool below, Size area) {
      final pts = _series(sel, maxV, startX, slot, mid, half, below);
      final line = _smoothPath(pts);
      final fill = Path.from(line)
        ..lineTo(pts.last.dx, mid)
        ..lineTo(pts.first.dx, mid)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: below ? Alignment.topCenter : Alignment.bottomCenter,
            end: below ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, area.width, area.height)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      final last = pts.last;
      canvas.drawCircle(last, 4, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(last, 2, Paint()..color = color);
    }

    draw((p) => p.down, maxDown, downColor, false, areaSize);
    draw((p) => p.up, maxUp, upColor, true, areaSize);
  }

  void _step(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    void draw(double Function(TrafficPoint) sel, double maxV, Color color,
        bool below) {
      final path = Path();
      var prevY = mid;
      for (var i = 0; i < points.length; i++) {
        final x = startX + slot * i;
        final v = sel(points[i]).clamp(0.0, maxV) / maxV;
        final y = below ? mid + v * half : mid - v * half;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, prevY);
          path.lineTo(x, y);
        }
        prevY = y;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    draw((p) => p.down, maxDown, downColor, false);
    draw((p) => p.up, maxUp, upColor, true);
  }

  void _ecg(Canvas canvas, double startX, double slot, double maxUp,
      double maxDown, double mid, double half) {
    void draw(double Function(TrafficPoint) sel, double maxV, Color color,
        bool below) {
      final path = Path()..moveTo(startX - slot, mid);
      for (var i = 0; i < points.length; i++) {
        final x = startX + slot * i;
        final v = sel(points[i]).clamp(0.0, maxV) / maxV;
        final amp = v * half;
        path.lineTo(x - slot * 0.3, mid + (below ? amp * 0.2 : -amp * 0.2));
        path.lineTo(x, below ? mid + amp : mid - amp);
        path.lineTo(x + slot * 0.3, mid);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    draw((p) => p.down, maxDown, downColor, false);
    draw((p) => p.up, maxUp, upColor, true);
  }
}

// ---------------------------------------------------------------- 网络信息

class _NetworkInfoCard extends ConsumerStatefulWidget {
  const _NetworkInfoCard();

  @override
  ConsumerState<_NetworkInfoCard> createState() => _NetworkInfoCardState();
}

class _NetworkInfoCardState extends ConsumerState<_NetworkInfoCard> {
  String? _localIp;
  String _iface = '';
  bool _masked = kShots;
  String? _publicIp;
  String _region = '';
  bool _loadingPublic = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _loadPublic();
  }

  Future<void> _loadLocal() async {
    final info = await localNetworkInfo();
    if (mounted && info != null) {
      setState(() {
        _localIp = info.$1;
        _iface = info.$2;
      });
    }
  }

  Future<void> _loadPublic() async {
    if (mounted) setState(() => _loadingPublic = true);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 6),
    ));

    var ok = false;
    try {
      final r = await dio.get('https://ipinfo.io/json');
      final d = r.data;
      if (d is Map) {
        final loc = d['loc']?.toString();
        var lat = loc != null && loc.contains(',')
            ? double.tryParse(loc.split(',').first.trim())
            : null;
        var lon = loc != null && loc.contains(',')
            ? double.tryParse(loc.split(',').last.trim())
            : null;
        _applyGeo(
          ip: d['ip']?.toString(),
          region: [d['country'], d['city'], d['org']]
              .where((e) => e != null && e.toString().isNotEmpty)
              .join(' · '),
          lat: lat,
          lon: lon,
          city: (d['city'] ?? d['country'] ?? '本地').toString(),
        );
        ok = lat != null && lon != null;
      }
    } catch (_) {}

    if (!ok) {
      try {
        final r = await dio.get('https://api.ip.sb/geoip');
        final d = r.data;
        if (d is Map) {
          _applyGeo(
            ip: d['ip']?.toString(),
            region: [d['country'], d['city'], d['isp']]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(' · '),
            lat: (d['latitude'] as num?)?.toDouble(),
            lon: (d['longitude'] as num?)?.toDouble(),
            city: (d['city'] ?? d['country'] ?? '本地').toString(),
          );
          ok = true;
        }
      } catch (_) {}
    }

    if (!ok) {
      try {
        final r = await dio.get('https://ipapi.co/json/');
        final d = r.data;
        if (d is Map) {
          _applyGeo(
            ip: d['ip']?.toString(),
            region: [d['country_name'], d['city'], d['org']]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(' · '),
            lat: (d['latitude'] as num?)?.toDouble(),
            lon: (d['longitude'] as num?)?.toDouble(),
            city: (d['city'] ?? d['country_name'] ?? '本地').toString(),
          );
          ok = true;
        }
      } catch (_) {}
    }

    if (!ok && mounted) setState(() => _publicIp = null);
    if (mounted) setState(() => _loadingPublic = false);
  }

  String _mask(String? ip) {
    if (ip == null || ip.isEmpty) return '—';
    // 逐字符替换成 *，长度保持一致
    return '*' * ip.length;
  }

  void _applyGeo({
    String? ip,
    required String region,
    double? lat,
    double? lon,
    required String city,
  }) {
    if (!mounted) return;
    setState(() {
      _publicIp = ip;
      _region = region;
    });
    if (lat != null && lon != null) {
      ref.read(localGeoProvider.notifier).set(GeoPoint(lat, lon, city));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);

    Widget row(String label, String value, {bool mono = true}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Text(label,
                  style: TextStyle(color: s.textTertiary, fontSize: 11.5)),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                style: TextStyle(
                  color: s.textPrimary,
                  fontSize: _masked ? 14.5 : 12.5,
                  letterSpacing: _masked ? 1.5 : 0,
                  fontWeight: FontWeight.w600,
                  fontFeatures:
                      mono ? const [FontFeature.tabularFigures()] : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlimpseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.language_rounded,
            title: '网络信息',
            trailing: [
              JellyPress(
                haptic: false,
                onTap: () => setState(() => _masked = !_masked),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: s.block,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _masked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 13,
                    color: s.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              JellyPress(
                haptic: false,
                onTap: _loadPublic,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: s.block,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _loadingPublic
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        )
                      : Icon(Icons.refresh_rounded,
                          size: 13, color: s.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row('内网 IP', _masked ? _mask(_localIp) : (_localIp ?? '—')),
          row('网卡', _iface.isEmpty ? '—' : _iface),
          row('外网 IP',
              _masked ? _mask(_publicIp) : (_publicIp ?? (_loadingPublic ? '查询中…' : '—'))),
          if (_region.isNotEmpty || kShots)
            row(
              '归属',
              kShots
                  ? '中国 · 上海 · 示例网络'
                  : (_masked ? '*' * _region.length : _region),
              mono: false,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _publicIp == null ? s.textTertiary : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _publicIp == null ? '未获取到外网信息' : '外网连通',
                style: TextStyle(color: s.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 出站模式

class _OutboundModeCard extends ConsumerWidget {
  const _OutboundModeCard();

  static const _modes = [
    ('rule', '规则', Icons.rule_rounded),
    ('global', '全局', Icons.public_rounded),
    ('direct', '直连', Icons.link_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final mode = ref.watch(outboundModeProvider);
    // 浅色强调色时用深色文字，避免白字看不清
    final onAccent = ThemeData.estimateBrightnessForColor(cs.primary) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return GlimpseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeader(icon: Icons.alt_route_rounded, title: '出站模式'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: s.block,
              borderRadius: BorderRadius.circular(Radii.block),
            ),
            child: Row(
              children: [
                for (final (id, label, icon) in _modes)
                  Expanded(
                    child: JellyPress(
                      onTap: () =>
                          ref.read(outboundModeProvider.notifier).set(id),
                      scaleTo: 0.95,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: mode == id ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: mode == id ? onAccent : s.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                color:
                                    mode == id ? onAccent : s.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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

// ---------------------------------------------------------------- 延时

class _LatencyCard extends ConsumerStatefulWidget {
  const _LatencyCard();

  @override
  ConsumerState<_LatencyCard> createState() => _LatencyCardState();
}

class _LatencyCardState extends ConsumerState<_LatencyCard> {
  static const _targets = [
    ('Baidu', 'https://www.baidu.com'),
    ('YouTube', 'https://www.youtube.com'),
    ('GitHub', 'https://github.com'),
    ('Cloudflare', 'https://www.cloudflare.com'),
  ];

  final Map<String, int?> _result = {};
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _test();
    });
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() => _testing = true);
    if (ref.read(settingsProvider).demoMode) {
      // 截图用：给几个像样的样例延时
      const sample = {'百度': 28, 'YouTube': 182, 'GitHub': 96, 'Cloudflare': 41};
      setState(() {
        _result
          ..clear()
          ..addAll(sample);
        _testing = false;
      });
      return;
    }
    try {
    final client = ref.read(clientProvider);

    String? currentNode;
    final proxies = await client?.proxies() ?? const {};
    final groups = proxies.values.where((p) => p.isGroup).toList();
    currentNode = groups.isNotEmpty ? groups.first.now : null;

    final results = <String, int?>{};
    for (final (label, url) in _targets) {
      int? delay;
      if (client != null && currentNode != null) {
        delay = await client.testDelay(currentNode, url: url, timeout: 5000);
      }
      results[label] = delay;
      if (mounted) setState(() => _result[label] = delay);
    }
    if (mounted) {
      setState(() {
        _result.addAll(results);
        _testing = false;
      });
    }
    } catch (_) {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;

    return GlimpseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            icon: Icons.speed_rounded,
            title: '延时',
            trailing: [
              JellyPress(
                haptic: false,
                onTap: _test,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: s.block,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        )
                      : Icon(Icons.speed_rounded,
                          size: 16, color: s.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (label, _) in _targets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style:
                            TextStyle(color: s.textPrimary, fontSize: 12.5)),
                  ),
                  _LatencyBar(
                    value: _result[label],
                    color: delayColor(_result[label], cs),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _result[label] == null
                          ? '—'
                          : (_result[label]! < 0
                              ? '超时'
                              : '${_result[label]}ms'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: delayColor(_result[label], cs),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_result.isEmpty && !_testing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('点右上角测速，测试当前节点到各站点的延时',
                  style: TextStyle(color: s.textTertiary, fontSize: 10)),
            ),
        ],
      ),
    );
  }
}

class _LatencyBar extends StatelessWidget {
  const _LatencyBar({required this.value, required this.color});

  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final v = value;
    final ratio =
        (v == null || v < 0) ? 0.0 : (v / 600).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 86,
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Stack(
          children: [
            Container(color: s.block),
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 小卡片

class SmallCard extends StatelessWidget {
  const SmallCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    return GlimpseCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: s.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: s.textSecondary, fontSize: 11.5),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _ConnStatsCard extends ConsumerStatefulWidget {
  const _ConnStatsCard();

  @override
  ConsumerState<_ConnStatsCard> createState() => _ConnStatsCardState();
}

class _ConnStatsCardState extends ConsumerState<_ConnStatsCard> {
  final List<double> _points = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // 停在其他页面时不采样（页面仍在 Offstage 缓存里）
      if (ref.read(activeTabProvider) != 0) return;
      final n = ref.read(connectionsProvider).value?.length ?? 0;
      setState(() {
        _points.add(n.toDouble());
        if (_points.length > 40) _points.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final cs = Theme.of(context).colorScheme;
    final conns = ref.watch(connectionsProvider).value ?? const [];
    var up = 0;
    var down = 0;
    for (final c in conns) {
      up += c.upload;
      down += c.download;
    }

    return SmallCard(
      icon: Icons.link_rounded,
      label: '连接统计',
      onTap: null,
      trailing: Text(
        '${conns.length} 条',
        style: TextStyle(
          color: s.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 连接数走势（心率式折线）
          SizedBox(
            height: 36,
            width: double.infinity,
            child: CustomPaint(
              painter: _PulsePainter(
                points: _points.isEmpty ? const [0, 0, 0] : _points,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('↑ ${fmtBytes(up)}   ↓ ${fmtBytes(down)}',
              maxLines: 1,
              style: TextStyle(
                color: s.textTertiary,
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

/// 内核占用：数字 + 心率式内存曲线（无进度条）
class _MemoryCoreCard extends ConsumerWidget {
  const _MemoryCoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final mem = ref.watch(memoryProvider).value;
    final history = ref.watch(memoryHistoryProvider);
    final version = ref.watch(versionProvider);
    final used = mem?.inuse ?? 0;
    final cs = Theme.of(context).colorScheme;

    return SmallCard(
      icon: Icons.monitor_heart_outlined,
      label: '内核占用',
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MetricNumber(fmtBytes(used), size: 19),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: version.hasValue ? AppColors.success : s.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: CustomPaint(
              painter: _PulsePainter(
                points: history,
                color: cs.primary,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

/// 心率式曲线：平滑走线 + 底部渐隐填充
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var minV = points.first;
    var maxV = points.first;
    for (final p in points) {
      minV = math.min(minV, p);
      maxV = math.max(maxV, p);
    }
    final span = math.max(1.0, maxV - minV);
    final stepX = size.width / (points.length - 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = stepX * i;
      final norm = (points[i] - minV) / span;
      final y = size.height - 3 - norm * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.points != points || old.color != color;
}

// ---------------------------------------------------------------- 编辑弹层


/// 可编辑卡片：长按进入编辑态，抖动 + 删除 + 排序
class _Editable extends ConsumerStatefulWidget {
  const _Editable({
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  ConsumerState<_Editable> createState() => _EditableState();
}

class _EditableState extends ConsumerState<_Editable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  @override
  void dispose() {
    _jiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = ref.watch(dashboardEditProvider);
    if (editing) {
      if (!_jiggle.isAnimating) _jiggle.repeat(reverse: true);
    } else if (_jiggle.isAnimating) {
      _jiggle.stop();
      _jiggle.value = 0;
    }

    final card = GestureDetector(
      onLongPress: () => ref.read(dashboardEditProvider.notifier).set(true),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (editing) ...[
            Positioned(
              top: -8,
              right: -6,
              child: JellyPress(
                haptic: false,
                onTap: () =>
                    ref.read(dashboardCardsProvider.notifier).toggle(widget.id),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: -8,
              left: -6,
              child: Row(
                children: [
                  _OrderBtn(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onTap: () => ref
                        .read(dashboardCardsProvider.notifier)
                        .move(widget.id, -1),
                  ),
                  const SizedBox(width: 4),
                  _OrderBtn(
                    icon: Icons.keyboard_arrow_down_rounded,
                    onTap: () => ref
                        .read(dashboardCardsProvider.notifier)
                        .move(widget.id, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return AnimatedBuilder(
        animation: _jiggle,
        builder: (context, child) {
          final angle = editing ? (_jiggle.value - 0.5) * 0.02 : 0.0;
          return Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: editing ? 0.97 : 1.0,
              child: child,
            ),
          );
        },
        child: card,
    );
  }
}

class _OrderBtn extends StatelessWidget {
  const _OrderBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JellyPress(
      haptic: false,
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: Colors.white),
      ),
    );
  }
}


/// 仪表盘卡片管理：开关 + 排序（隐藏的卡片也能重新打开）
class _DashboardEditor extends ConsumerWidget {
  const _DashboardEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = surfacesOf(context);
    final active = ref.watch(dashboardCardsProvider);
    final notifier = ref.read(dashboardCardsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('卡片管理',
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
                JellyTextButton(
                  label: '恢复默认',
                  onPressed: notifier.reset,
                ),
              ],
            ),
            Text('关闭的卡片会从首页隐藏，随时可以在这里打开',
                style: TextStyle(color: s.textTertiary, fontSize: 11)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final id in kDashboardCards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InnerBlock(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                kDashboardCardLabels[id] ?? id,
                                style: TextStyle(
                                    color: s.textPrimary, fontSize: 13.5),
                              ),
                            ),
                            if (active.contains(id)) ...[
                              _MiniArrow(
                                icon: Icons.keyboard_arrow_up_rounded,
                                onTap: () => notifier.move(id, -1),
                              ),
                              _MiniArrow(
                                icon: Icons.keyboard_arrow_down_rounded,
                                onTap: () => notifier.move(id, 1),
                              ),
                            ],
                            Switch.adaptive(
                              value: active.contains(id),
                              onChanged: (_) => notifier.toggle(id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniArrow extends StatelessWidget {
  const _MiniArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JellyPress(
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: surfacesOf(context).textSecondary),
      ),
    );
  }
}

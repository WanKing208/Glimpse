import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/jelly.dart';
import '../core/theme.dart';

/// 色盘取色：角度=色相，半径=饱和度，另有明度滑块
Future<Color?> showColorWheel(
  BuildContext context, {
  Color? initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorWheelDialog(initial: initial ?? AppColors.primary),
  );
}

class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  static const double _size = 218;

  void _pick(Offset local) {
    final c = const Offset(_size / 2, _size / 2);
    final v = local - c;
    final dist = v.distance;
    final r = _size / 2;
    if (dist > r) return;
    var hue = math.atan2(v.dy, v.dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    final sat = (dist / r).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv
          .withHue(hue)
          .withSaturation(sat)
          .withValue(_hsv.value.clamp(0.25, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = surfacesOf(context);
    final color = _hsv.toColor();

    return Dialog(
      backgroundColor: s.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('自定义颜色',
                      style: TextStyle(
                          color: s.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                JellyPress(
                  haptic: false,
                  onTap: () => Navigator.of(context).pop(),
                  scaleTo: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: s.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTapDown: (d) => _pick(d.localPosition),
              onPanUpdate: (d) => _pick(d.localPosition),
              child: SizedBox(
                width: _size,
                height: _size,
                child: CustomPaint(
                  painter: _WheelPainter(value: _hsv.value),
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('明度',
                    style: TextStyle(color: s.textSecondary, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _hsv.value,
                      min: 0.2,
                      max: 1.0,
                      onChanged: (v) =>
                          setState(() => _hsv = _hsv.withValue(v)),
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: s.hairline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: JellyTextButton(
                    label: '取消',
                    onPressed: () => Navigator.of(context).pop(),
                    color: s.textSecondary,
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(color),
                    child: const Text('使用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final hueColors = [
      for (var i = 0; i <= 36; i++)
        HSVColor.fromAHSV(1, (i * 10) % 360, 1, 1).toColor(),
    ];
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: hueColors,
          startAngle: 0,
          endAngle: math.pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 中心去饱和
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // 明度压暗
    if (value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: (1 - value) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.value != value;
}

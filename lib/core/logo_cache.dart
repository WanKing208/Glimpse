import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

/// 分组/机场 logo 的内存缓存：同一个地址只下载一次，避免每次切页重拉
class LogoCache {
  LogoCache._();

  static final Map<String, Uint8List> _bytes = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static Uint8List? peek(String url) => _bytes[url];

  static Future<Uint8List?> load(String url) {
    final cached = _bytes[url];
    if (cached != null) return Future.value(cached);
    return _inflight[url] ??= _fetch(url);
  }

  static Future<Uint8List?> _fetch(String url) async {
    try {
      final r = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = r.data;
      if (data == null || data.isEmpty) return null;
      final bytes = Uint8List.fromList(data);
      _bytes[url] = bytes;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _inflight.remove(url);
    }
  }
}

/// 带缓存的网络 logo
class CachedLogo extends StatelessWidget {
  const CachedLogo({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.radius,
  });

  final String url;
  final double size;
  final Widget fallback;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final cached = LogoCache.peek(url);
    if (cached != null) return _wrap(_image(cached));

    return FutureBuilder<Uint8List?>(
      future: LogoCache.load(url),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          // 加载中或失败都先显示占位，不闪
          return _wrap(fallback);
        }
        return _wrap(_image(data));
      },
    );
  }

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );

  Widget _wrap(Widget child) => SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius ?? size * 0.28),
          child: child,
        ),
      );
}

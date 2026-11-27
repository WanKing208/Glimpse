import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';
import 'ws.dart';

/// mihomo 外部控制 REST + WebSocket 客户端
class MihomoClient {
  MihomoClient({required String baseUrl, this.secret})
      : baseUrl = _normalize(baseUrl);

  final String baseUrl;
  final String? secret;

  Dio? _dio;

  static String _normalize(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Map<String, String> get _headers => {
        if (secret != null && secret!.isNotEmpty)
          'Authorization': 'Bearer $secret',
      };

  Dio get dio => _dio ??= Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 12),
        headers: _headers,
        validateStatus: (s) => s != null && s < 400,
      ));

  Uri wsUri(String path, [Map<String, String>? query]) {
    final b = Uri.parse(baseUrl);
    return b.replace(
      scheme: b.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: query,
    );
  }

  WebSocketChannel _open(String path, [Map<String, String>? query]) =>
      openSocket(wsUri(path, query), headers: _headers);

  // ---------- REST ----------

  Future<String> version() async {
    final r = await dio.get('/version');
    final data = r.data;
    if (data is Map && data['version'] != null) return data['version'].toString();
    return 'unknown';
  }

  Future<Map<String, MihomoProxy>> proxies() async {
    final r = await dio.get('/proxies');
    final data = r.data;
    final map = <String, MihomoProxy>{};
    if (data is Map && data['proxies'] is Map) {
      (data['proxies'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          map[k.toString()] = MihomoProxy.fromJson(k.toString(), v);
        } else if (v is Map) {
          map[k.toString()] =
              MihomoProxy.fromJson(k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }
    return map;
  }

  Future<void> selectProxy(String group, String name) async {
    await dio.put('/proxies/${Uri.encodeComponent(group)}',
        data: {'name': name}, options: Options(contentType: 'application/json'));
  }

  Future<int?> testDelay(String name,
      {String url = 'https://www.gstatic.com/generate_204',
      int timeout = 5000}) async {
    try {
      final r = await dio.get(
        '/proxies/${Uri.encodeComponent(name)}/delay',
        queryParameters: {'url': url, 'timeout': timeout},
      );
      final d = r.data is Map ? (r.data as Map)['delay'] : null;
      if (d is num) return d.toInt();
      return r.statusCode == 200 ? null : -1;
    } catch (_) {
      return -1;
    }
  }

  Future<Map<String, int>> testGroupDelay(String group,
      {String? url = 'https://www.gstatic.com/generate_204',
      int timeout = 5000}) async {
    final r = await dio.get(
      '/group/${Uri.encodeComponent(group)}/delay',
      queryParameters: {
        if (url != null) 'url': url,
        'timeout': timeout,
      },
    );
    final out = <String, int>{};
    if (r.data is Map) {
      (r.data as Map).forEach((k, v) {
        if (v is num) out[k.toString()] = v.toInt();
      });
    }
    return out;
  }

  Future<Map<String, ProviderInfo>> providers() async {
    final r = await dio.get('/providers/proxies');
    final out = <String, ProviderInfo>{};
    final data = r.data;
    if (data is Map && data['providers'] is Map) {
      (data['providers'] as Map).forEach((k, v) {
        if (v is Map) {
          out[k.toString()] =
              ProviderInfo.fromJson(k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }
    return out;
  }

  /// 供应商内单个节点测速
  Future<int?> testProviderNode(
    String provider,
    String node, {
    String url = 'https://www.gstatic.com/generate_204',
    int timeout = 5000,
  }) async {
    try {
      final r = await dio.get(
        '/providers/proxies/${Uri.encodeComponent(provider)}'
        '/${Uri.encodeComponent(node)}/healthcheck',
        queryParameters: {'url': url, 'timeout': timeout},
      );
      final d = r.data is Map ? (r.data as Map)['delay'] : null;
      if (d is num) return d.toInt();
      return -1;
    } catch (_) {
      return -1;
    }
  }

  /// 供应商全量测速：返回 节点名 -> 延时
  Future<Map<String, int>> testProviderAll(
    String provider, {
    String? url,
    int timeout = 5000,
  }) async {
    try {
      final r = await dio.get(
        '/providers/proxies/${Uri.encodeComponent(provider)}/healthcheck',
        queryParameters: {
          if (url != null) 'url': url,
          'timeout': timeout,
        },
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      final out = <String, int>{};
      if (r.data is Map) {
        (r.data as Map).forEach((k, v) {
          final n = asInt(v);
          if (n != null) out[k.toString()] = n;
        });
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<void> updateProvider(String name) async {
    await dio.put('/providers/proxies/${Uri.encodeComponent(name)}');
  }

  Future<Map<String, RuleProviderInfo>> ruleProviders() async {
    final r = await dio.get('/providers/rules');
    final out = <String, RuleProviderInfo>{};
    final data = r.data;
    if (data is Map && data['providers'] is Map) {
      (data['providers'] as Map).forEach((k, v) {
        if (v is Map) {
          out[k.toString()] = RuleProviderInfo.fromJson(
              k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }
    return out;
  }

  Future<void> updateRuleProvider(String name) async {
    await dio.put('/providers/rules/${Uri.encodeComponent(name)}');
  }

  Future<List<RuleEntry>> rules() async {
    final r = await dio.get('/rules');
    final data = r.data;
    if (data is Map && data['rules'] is List) {
      return (data['rules'] as List)
          .whereType<Map>()
          .map((e) => RuleEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// 启用/停用单条规则（mihomo ≥ 1.19）
  Future<void> setRulesDisabled(Map<int, bool> changes) async {
    await dio.patch('/rules/disable', data: changes);
  }

  /// 让指定规则重新匹配现有连接
  Future<void> refindRule(String uuid) async {
    if (uuid.isEmpty) return;
    await dio.put('/rules/${Uri.encodeComponent(uuid)}');
  }

  /// 重启内核（需要内核以 /restart 端点运行）
  Future<void> restartCore() async {
    await dio.post('/restart');
  }

  /// 重新载入配置
  Future<void> reloadConfigs({bool force = false}) async {
    await dio.put('/configs${force ? '?force=true' : ''}',
        data: {'path': '', 'payload': ''});
  }

  /// 清空 DNS 缓存
  Future<void> flushDnsCache() async {
    await dio.post('/cache/dns/flush');
  }

  /// 清空 FakeIP 缓存
  Future<void> flushFakeIpCache() async {
    await dio.post('/cache/fakeip/flush');
  }

  /// 更新 GEO 数据库
  Future<void> updateGeo() async {
    await dio.post('/configs/geo');
  }

  /// 修改运行时配置（端口、局域网等）
  Future<void> patchConfigs(Map<String, dynamic> body) async {
    await dio.patch('/configs', data: body);
  }

  Future<void> setMode(String mode) async {
    await dio.patch('/configs', data: {'mode': mode});
  }

  Future<Map<String, dynamic>> configs() async {
    final r = await dio.get('/configs');
    return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : {};
  }

  Future<void> closeConnection(String id) async {
    await dio.delete('/connections/${Uri.encodeComponent(id)}');
  }

  Future<void> closeAllConnections() async {
    await dio.delete('/connections');
  }

  // ---------- WebSocket ----------

  Stream<TrafficSample> traffic() {
    final ch = _open('/traffic');
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      return TrafficSample(
        (m['up'] as num?)?.toInt() ?? 0,
        (m['down'] as num?)?.toInt() ?? 0,
        upTotal: (m['uploadTotal'] as num?)?.toInt(),
        downTotal: (m['downloadTotal'] as num?)?.toInt(),
      );
    });
  }

  Stream<MemorySample> memory() {
    final ch = _open('/memory');
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      return MemorySample(
        (m['inuse'] as num?)?.toInt() ?? 0,
        (m['oslimit'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Stream<LogLine> logs({String level = 'info'}) {
    final ch = _open('/logs', {'level': level});
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      return LogLine(
        (m['type'] ?? 'info').toString(),
        (m['payload'] ?? '').toString(),
        DateTime.now(),
      );
    });
  }

  Stream<List<ConnectionInfo>> connections({
    void Function(int up, int down)? onTotals,
  }) {
    final ch = _open('/connections');
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      final up = asInt(m['uploadTotal']);
      final down = asInt(m['downloadTotal']);
      if (up != null && down != null) onTotals?.call(up, down);
      final list = (m['connections'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ConnectionInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }
}

/// mihomo 数据模型（与 REST / WS 返回结构一致）
library;

/// 容错取整数：内核有的字段会返回字符串
int? asInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return fallback;
}

class MihomoProxy {
  const MihomoProxy({
    required this.name,
    required this.type,
    this.delay,
    this.now,
    this.all = const [],
    this.udp = false,
    this.history = const [],
    this.provider,
    this.icon,
    this.groupHint = false,
    this.ipVersion,
    this.extra = const {},
    this.xudp = false,
  });

  MihomoProxy copyWith({int? delay, String? now}) => MihomoProxy(
        name: name,
        type: type,
        delay: delay ?? this.delay,
        now: now ?? this.now,
        all: all,
        udp: udp,
        history: history,
        provider: provider,
        icon: icon,
        groupHint: groupHint,
        ipVersion: ipVersion,
        extra: extra,
        xudp: xudp,
      );

  final String name;
  final String type;
  final int? delay;
  final String? now;
  final List<String> all;
  final bool udp;
  final List<int> history;
  final String? provider;

  /// 配置里给分组/节点写的 logo 地址
  final String? icon;

  /// IP 版本（部分内核会返回 ip-version 字段）
  final String? ipVersion;

  /// 按测试 URL 记录的历史延时（内核返回的 extra 字段）
  final Map<String, int> extra;

  /// 是否支持 xudp
  final bool xudp;

  /// 占位分组：内核返回的 all 里有名字，但代理表里查不到对象
  final bool groupHint;

  bool get isGroup {
    if (all.isNotEmpty || groupHint) return true;
    // 内核返回的分组有时 all 为空（配置重载中、组里还没节点），按类型兜底
    final t = type.toLowerCase();
    return t == 'selector' ||
        t == 'urltest' ||
        t == 'url-test' ||
        t == 'fallback' ||
        t == 'loadbalance' ||
        t == 'load-balance' ||
        t == 'relay';
  }

  factory MihomoProxy.fromJson(String key, Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final history = <int>[];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is Map && h['delay'] is num) history.add((h['delay'] as num).toInt());
      }
    }
    int? delay;
    if (history.isNotEmpty) delay = history.last;
    delay = asInt(json['delay']) ?? delay;

    return MihomoProxy(
      name: json['name'] as String? ?? key,
      type: json['type'] as String? ?? 'Unknown',
      delay: delay,
      now: json['now'] as String?,
      all: (json['all'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      udp: asBool(json['udp']),
      history: history,
      provider: json['provider'] as String?,
      icon: (json['icon'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['icon'] as String?,
      xudp: asBool(json['xudp']),
      ipVersion: (json['ip-version'] ??
              json['ipVersion'] ??
              json['ip_version'] ??
              json['ipversion'])
          ?.toString(),
      extra: _parseExtra(json['extra']),
    );
  }
}

class RuleEntry {
  const RuleEntry({
    required this.type,
    required this.payload,
    required this.proxy,
    this.size = 0,
    this.index = -1,
    this.uuid = '',
    this.disabled = false,
  });

  final String type;
  final String payload;
  final String proxy;
  final int size;

  /// 内核返回的规则序号，用于 PATCH /rules/disable
  final int index;

  /// 规则 uuid，用于 PUT /rules/{uuid} 重新匹配
  final String uuid;
  final bool disabled;

  RuleEntry copyWith({bool? disabled}) => RuleEntry(
        type: type,
        payload: payload,
        proxy: proxy,
        size: size,
        index: index,
        uuid: uuid,
        disabled: disabled ?? this.disabled,
      );

  factory RuleEntry.fromJson(Map<String, dynamic> j) => RuleEntry(
        type: j['type'] as String? ?? '',
        payload: j['payload'] as String? ?? '',
        proxy: j['proxy'] as String? ?? '',
        size: asInt(j['size']) ?? 0,
        index: asInt(j['index']) ?? -1,
        uuid: j['uuid']?.toString() ?? '',
        disabled: asBool(j['disabled']),
      );
}

class ConnectionInfo {
  const ConnectionInfo({
    required this.id,
    required this.host,
    required this.destinationIP,
    required this.network,
    required this.type,
    required this.rule,
    required this.rulePayload,
    required this.chains,
    required this.upload,
    required this.download,
    required this.start,
    this.sourceIP,
    this.sourcePort,
    this.destinationPort,
    this.processPath,
    this.sniffHost,
  });

  final String id;
  final String host;
  final String destinationIP;
  final String network;
  final String type;
  final String rule;
  final String rulePayload;
  final List<String> chains;
  final int upload;
  final int download;
  final DateTime start;
  final String? sourceIP;
  final String? sourcePort;
  final String? destinationPort;
  final String? processPath;
  final String? sniffHost;

  String get chainText => chains.reversed.join(' → ');
  int get total => upload + download;

  factory ConnectionInfo.fromJson(Map<String, dynamic> j) {
    final meta = (j['metadata'] as Map?) ?? const {};
    String s(String k) => (meta[k] ?? '').toString();
    return ConnectionInfo(
      id: j['id']?.toString() ?? '',
      host:
          (s('host').isNotEmpty ? s('host') : (s('sniffHost').isNotEmpty ? s('sniffHost') : s('destinationIP'))),
      destinationIP: s('destinationIP'),
      network: s('network'),
      type: s('type'),
      rule: j['rule']?.toString() ?? '',
      rulePayload: j['rulePayload']?.toString() ?? '',
      chains: (j['chains'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      upload: asInt(j['upload']) ?? 0,
      download: asInt(j['download']) ?? 0,
      start: DateTime.tryParse(j['start']?.toString() ?? '') ?? DateTime.now(),
      sourceIP: s('sourceIP'),
      sourcePort: s('sourcePort'),
      destinationPort: s('destinationPort'),
      processPath: s('processPath'),
      sniffHost: s('sniffHost'),
    );
  }
}

class TrafficSample {
  const TrafficSample(this.up, this.down, {this.upTotal, this.downTotal});
  final int up;
  final int down;

  /// 内核开机以来的累计（mihomo 的 /traffic 帧自带）
  final int? upTotal;
  final int? downTotal;
}

class MemorySample {
  const MemorySample(this.inuse, this.oslimit);
  final int inuse;
  final int oslimit;
}

class LogLine {
  const LogLine(this.type, this.payload, this.time);
  final String type;
  final String payload;
  final DateTime time;
}

class TrafficPoint {
  const TrafficPoint(this.up, this.down);
  final double up;
  final double down;
}


/// 代理供应商（机场）：/providers/proxies
class ProviderInfo {
  const ProviderInfo({
    required this.name,
    required this.type,
    required this.vehicleType,
    required this.nodes,
    this.icon,
    this.proxies = const [],
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.updatedAt,
    this.homepage,
    this.testUrl,
  });

  final String name;
  final String type;
  final String vehicleType;
  final List<String> nodes;
  final String? icon;

  /// 供应商下的完整节点对象（用于补齐节点表）
  final List<MihomoProxy> proxies;
  final int upload;
  final int download;
  final int total;
  final DateTime? expire;
  final DateTime? updatedAt;
  final String? homepage;

  /// 该供应商配置的测速地址
  final String? testUrl;

  int get used => upload + download;
  double get ratio =>
      total <= 0 ? 0 : (used / total).clamp(0.0, 1.0).toDouble();
  int get remain => total <= 0 ? 0 : (total - used).clamp(0, total);

  /// 距离到期还有几天，负数表示已过期
  int? get daysLeft {
    final e = expire;
    if (e == null) return null;
    return e.difference(DateTime.now()).inDays;
  }

  factory ProviderInfo.fromJson(String key, Map<String, dynamic> j) {
    final sub = (j['subscriptionInfo'] as Map?) ?? const {};
    int n(String k) => asInt(sub[k]) ?? 0;
    final expireSec = asInt(sub['Expire']) ?? 0;
    final updatedRaw = j['updatedAt'];
    final updateSec = asInt(updatedRaw) ??
        (updatedRaw is String
            ? DateTime.tryParse(updatedRaw)?.millisecondsSinceEpoch ?? 0
            : 0);
    final proxies = (j['proxies'] as List?) ?? const [];
    return ProviderInfo(
      name: j['name']?.toString() ?? key,
      type: j['type']?.toString() ?? 'Proxy',
      vehicleType: j['vehicleType']?.toString() ?? 'HTTP',
      nodes: proxies
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      icon: (j['icon'] as String?)?.trim().isEmpty ?? true
          ? null
          : j['icon'] as String?,
      upload: n('Upload'),
      download: n('Download'),
      total: n('Total'),
      proxies: proxies
          .whereType<Map>()
          .map((e) => MihomoProxy.fromJson(
              (e['name'] ?? '').toString(), Map<String, dynamic>.from(e)))
          .toList(),
      expire: expireSec > 0
          ? DateTime.fromMillisecondsSinceEpoch(expireSec * 1000)
          : null,
      updatedAt: updateSec > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              updateSec > 100000000000 ? updateSec : updateSec * 1000)
          : null,
      homepage: j['homepage']?.toString(),
      testUrl: (j['testUrl'] ?? j['test-url'])?.toString(),
    );
  }
}


/// 规则集供应商：/providers/rules
class RuleProviderInfo {
  const RuleProviderInfo({
    required this.name,
    required this.type,
    required this.behavior,
    required this.ruleCount,
    this.vehicleType = 'HTTP',
    this.updatedAt,
    this.format,
  });

  final String name;
  final String type;
  final String behavior;
  final int ruleCount;
  final String vehicleType;
  final DateTime? updatedAt;
  final String? format;

  factory RuleProviderInfo.fromJson(String key, Map<String, dynamic> j) {
    final updatedRaw = j['updatedAt'];
    final updated = asInt(updatedRaw) ??
        (updatedRaw is String
            ? DateTime.tryParse(updatedRaw)?.millisecondsSinceEpoch ?? 0
            : 0);
    return RuleProviderInfo(
      name: j['name']?.toString() ?? key,
      type: j['type']?.toString() ?? 'Rule',
      behavior: j['behavior']?.toString() ?? '-',
      ruleCount: asInt(j['ruleCount']) ?? 0,
      vehicleType: j['vehicleType']?.toString() ?? 'HTTP',
      updatedAt: updated > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              updated > 100000000000 ? updated : updated * 1000)
          : null,
      format: j['format']?.toString(),
    );
  }
}


/// 解析内核的 extra：{ url: { history: [{delay: 123}] } } → { url: 123 }
Map<String, int> _parseExtra(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  raw.forEach((k, v) {
    if (v is! Map) return;
    final history = v['history'];
    if (history is! List || history.isEmpty) return;
    final last = history.last;
    if (last is! Map) return;
    final d = asInt(last['delay']);
    if (d != null) out[k.toString()] = d;
  });
  return out;
}

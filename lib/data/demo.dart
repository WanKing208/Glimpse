import 'dart:async';
import 'dart:math';

import 'models.dart';

/// 演示后端：没有 mihomo 实例时也能看到完整界面
class DemoBackend {
  DemoBackend() {
    _buildProxies();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), _tickTraffic);
    _memTimer = Timer.periodic(const Duration(seconds: 2), _tickMemory);
    _connTimer = Timer.periodic(const Duration(seconds: 2), _tickConnections);
    _logTimer = Timer.periodic(const Duration(milliseconds: 2200), _tickLogs);
  }

  final _rnd = Random(7);
  final _trafficCtrl = StreamController<TrafficSample>.broadcast();
  final _memCtrl = StreamController<MemorySample>.broadcast();
  final _connCtrl = StreamController<List<ConnectionInfo>>.broadcast();
  final _logCtrl = StreamController<LogLine>.broadcast();

  late Timer _trafficTimer;
  late Timer _memTimer;
  late Timer _connTimer;
  late Timer _logTimer;

  final Map<String, MihomoProxy> proxies = {};
  final List<ConnectionInfo> connections = [];
  int _memInuse = 86 * 1024 * 1024;

  void dispose() {
    _trafficTimer.cancel();
    _memTimer.cancel();
    _connTimer.cancel();
    _logTimer.cancel();
    _trafficCtrl.close();
    _memCtrl.close();
    _connCtrl.close();
    _logCtrl.close();
  }

  void _buildProxies() {
    final groups = <String, List<String>>{
      'Proxy': [
        'HK-01-IPLC',
        'HK-02-BGP',
        'JP-02-vmess',
        'JP-03-trojan',
        'SG-03',
        'US-05',
        'TW-01',
        'KR-02',
      ],
      'Auto': ['HK-01-IPLC', 'JP-02-vmess', 'SG-03', 'US-05'],
      'Streaming': ['HK-02-BGP', 'JP-03-trojan', 'US-05'],
      'Google': ['手动节点', 'HK-01-IPLC'],
      'Telegram': ['手动节点', 'JP-02-vmess'],
      'AI 代理': ['SG-03', 'US-05', 'JP-03-trojan'],
      'TikTok': ['HK-02-BGP', 'TW-01'],
      '手动节点': ['HK-01-IPLC', 'TW-01', 'KR-02'],
    };

    final delays = <String, int>{
      'HK-01-IPLC': 32,
      'HK-02-BGP': 45,
      'JP-02-vmess': 58,
      'JP-03-trojan': 66,
      'SG-03': 88,
      'US-05': 152,
      'TW-01': 41,
      'KR-02': 73,
    };

    for (final entry in groups.entries) {
      proxies[entry.key] = MihomoProxy(
        name: entry.key,
        type: 'Selector',
        all: entry.value,
        now: entry.value.first,
      );
      for (final n in entry.value) {
        proxies.putIfAbsent(
          n,
          () => MihomoProxy(
            name: n,
            type: n.contains('trojan')
                ? 'Trojan'
                : n.contains('vmess')
                    ? 'Vmess'
                    : n.contains('IPLC')
                        ? 'IEPL'
                        : 'Shadowsocks',
            delay: delays[n],
            udp: true,
            history: [delays[n] ?? 0],
          ),
        );
      }
    }
    proxies['DIRECT'] = const MihomoProxy(name: 'DIRECT', type: 'Direct');
    proxies['REJECT'] = const MihomoProxy(name: 'REJECT', type: 'Reject');
  }

  void select(String group, String name) {
    final g = proxies[group];
    if (g == null) return;
    proxies[group] = MihomoProxy(
      name: g.name,
      type: g.type,
      all: g.all,
      now: name,
      delay: proxies[name]?.delay,
    );
  }

  Future<int?> testDelay(String name) async {
    await Future.delayed(Duration(milliseconds: 260 + _rnd.nextInt(500)));
    final base = proxies[name]?.delay ?? 120;
    final jitter = _rnd.nextInt(40) - 20;
    final d = (base + jitter).clamp(8, 900);
    final p = proxies[name];
    if (p != null) {
      proxies[name] = MihomoProxy(
        name: p.name,
        type: p.type,
        all: p.all,
        now: p.now,
        delay: d,
        udp: p.udp,
        history: [...p.history, d],
      );
    }
    return d;
  }

  Future<Map<String, int>> testGroup(String group) async {
    final g = proxies[group];
    if (g == null) return {};
    final out = <String, int>{};
    for (final n in g.all) {
      final d = await testDelay(n);
      if (d != null) out[n] = d;
    }
    return out;
  }

  Map<String, ProviderInfo> providers() {
    final hkNodes = proxies.values
        .where((p) => !p.isGroup && p.name.startsWith('HK'))
        .map((p) => p.name)
        .toList();
    final jpNodes = proxies.values
        .where((p) => !p.isGroup && p.name.startsWith('JP'))
        .map((p) => p.name)
        .toList();
    final now = DateTime.now();
    return {
      'Airport-HK': ProviderInfo(
        name: 'Airport-HK',
        type: 'Proxy',
        vehicleType: 'HTTP',
        nodes: hkNodes.isEmpty ? ['HK-01-IPLC', 'HK-02-BGP'] : hkNodes,
        total: 200 * 1024 * 1024 * 1024,
        upload: 12 * 1024 * 1024 * 1024,
        download: 96 * 1024 * 1024 * 1024,
        expire: now.add(const Duration(days: 46)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      'Airport-JP': ProviderInfo(
        name: 'Airport-JP',
        type: 'Proxy',
        vehicleType: 'HTTP',
        nodes: jpNodes.isEmpty ? ['JP-02-vmess', 'JP-03-trojan'] : jpNodes,
        total: 100 * 1024 * 1024 * 1024,
        upload: 4 * 1024 * 1024 * 1024,
        download: 71 * 1024 * 1024 * 1024,
        expire: now.add(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    };
  }

  Map<String, RuleProviderInfo> ruleProviders() {
    final now = DateTime.now();
    return {
      'geosite': RuleProviderInfo(
        name: 'geosite',
        type: 'Rule',
        behavior: 'domain',
        ruleCount: 1284,
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      'geoip': RuleProviderInfo(
        name: 'geoip',
        type: 'Rule',
        behavior: 'ipcidr',
        ruleCount: 942,
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      'adblock': RuleProviderInfo(
        name: 'adblock',
        type: 'Rule',
        behavior: 'domain',
        ruleCount: 5310,
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
    };
  }

  List<RuleEntry> rules() => const [
        RuleEntry(
            type: 'DomainSuffix',
            payload: 'google.com',
            proxy: 'Proxy',
            size: 1200,
            index: 0,
            uuid: 'demo-rule-0'),
        RuleEntry(
            type: 'DomainSuffix',
            payload: 'github.com',
            proxy: 'Proxy',
            size: 640,
            index: 1,
            uuid: 'demo-rule-1'),
        RuleEntry(
            type: 'DomainKeyword',
            payload: 'youtube',
            proxy: 'Streaming',
            size: 210,
            index: 2,
            uuid: 'demo-rule-2'),
        RuleEntry(
            type: 'DomainKeyword',
            payload: 'netflix',
            proxy: 'Streaming',
            size: 180,
            index: 3,
            uuid: 'demo-rule-3'),
        RuleEntry(
            type: 'IPCIDR',
            payload: '192.168.0.0/16',
            proxy: 'DIRECT',
            size: 90,
            index: 4,
            uuid: 'demo-rule-4'),
        RuleEntry(
            type: 'IPCIDR',
            payload: '10.0.0.0/8',
            proxy: 'DIRECT',
            size: 64,
            index: 5,
            uuid: 'demo-rule-5'),
        RuleEntry(
            type: 'GeoIP',
            payload: 'CN',
            proxy: 'DIRECT',
            size: 8800,
            index: 6,
            uuid: 'demo-rule-6'),
        RuleEntry(
            type: 'Match',
            payload: '',
            proxy: 'Proxy',
            size: 1,
            index: 7,
            uuid: 'demo-rule-7'),
      ];

  // ---- 定时器 ----

  void _tickTraffic(Timer _) {
    final up = 4 * 1024 + _rnd.nextInt(28 * 1024);
    final down = 120 * 1024 + _rnd.nextInt(1400 * 1024);
    _trafficCtrl.add(TrafficSample(up, down));
  }

  void _tickMemory(Timer _) {
    _memInuse += _rnd.nextInt(3 * 1024 * 1024) - 1024 * 1024;
    if (_memInuse < 48 * 1024 * 1024) _memInuse = 48 * 1024 * 1024;
    if (_memInuse > 220 * 1024 * 1024) _memInuse = 220 * 1024 * 1024;
    _memCtrl.add(MemorySample(_memInuse, 512 * 1024 * 1024));
  }

  void _tickConnections(Timer _) {
    final hosts = [
      'www.youtube.com',
      'api.github.com',
      'fonts.gstatic.com',
      'registry.npmjs.org',
      'i.ytimg.com',
      'cdn.jsdelivr.net',
      'www.google.com',
    ];
    if (connections.length < 12 && _rnd.nextBool()) {
      final h = hosts[_rnd.nextInt(hosts.length)];
      connections.insert(
        0,
        ConnectionInfo(
          id: 'demo-${_rnd.nextInt(1 << 30)}',
          host: h,
          destinationIP: '140.82.112.${_rnd.nextInt(200)}',
          network: 'tcp',
          type: 'HTTP',
          rule: 'DomainSuffix',
          rulePayload: h.split('.').skip(1).join('.'),
          chains: ['HK-01-IPLC', 'Proxy'],
          upload: _rnd.nextInt(200 * 1024),
          download: _rnd.nextInt(4 * 1024 * 1024),
          start: DateTime.now().subtract(Duration(seconds: _rnd.nextInt(600))),
        ),
      );
    } else if (connections.isNotEmpty && _rnd.nextInt(3) == 0) {
      connections.removeLast();
    }
    for (var i = 0; i < connections.length; i++) {
      final c = connections[i];
      connections[i] = ConnectionInfo(
        id: c.id,
        host: c.host,
        destinationIP: c.destinationIP,
        network: c.network,
        type: c.type,
        rule: c.rule,
        rulePayload: c.rulePayload,
        chains: c.chains,
        upload: c.upload + _rnd.nextInt(8 * 1024),
        download: c.download + _rnd.nextInt(120 * 1024),
        start: c.start,
      );
    }
    _connCtrl.add(List.unmodifiable(connections));
  }

  void _tickLogs(Timer _) {
    final samples = [
      ['info', '[TCP] 10.0.0.2:52133 --> www.youtube.com:443 match DomainKeyword(youtube) using Proxy'],
      ['info', '[TCP] 10.0.0.2:52140 --> api.github.com:443 match DomainSuffix(github.com) using Proxy'],
      ['warning', '[DNS] resolve cdn.jsdelivr.net failed, fallback to DoH'],
      ['info', '[UDP] 10.0.0.2:53001 --> 8.8.8.8:53 match GeoIP(CN) using DIRECT'],
      ['debug', '[TUN] accept connection from 10.0.0.2:52155'],
    ];
    final s = samples[_rnd.nextInt(samples.length)];
    _logCtrl.add(LogLine(s[0], s[1], DateTime.now()));
  }

  Stream<TrafficSample> get trafficStream => _trafficCtrl.stream;
  Stream<MemorySample> get memoryStream => _memCtrl.stream;
  Stream<List<ConnectionInfo>> get connectionsStream => _connCtrl.stream;
  Stream<LogLine> get logsStream => _logCtrl.stream;
}

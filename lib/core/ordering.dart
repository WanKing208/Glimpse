/// 分组与节点的排序规则：规则类分组靠前，区域节点按常见顺序往后
library;

/// 常见区域顺序（越靠前越优先）
const _regions = <String, int>{
  'hk': 0, 'hongkong': 0, 'hong kong': 0, '香港': 0, '深港': 0,
  'tw': 1, 'taiwan': 1, '台湾': 1, '台灣': 1,
  'jp': 2, 'japan': 2, '日本': 2, '东京': 2, '大阪': 2,
  'sg': 3, 'singapore': 3, '新加坡': 3, '狮城': 3,
  'us': 4, 'united states': 4, '美国': 4, '美國': 4, '洛杉矶': 4, '圣何塞': 4,
  'kr': 5, 'korea': 5, '韩国': 5, '首尔': 5,
  'uk': 6, 'gb': 6, 'britain': 6, '英国': 6, '伦敦': 6,
  'de': 7, 'germany': 7, '德国': 7, '法兰克福': 7,
  'au': 8, 'australia': 8, '澳大利亚': 8,
  'ca': 9, 'canada': 9, '加拿大': 9,
  'ru': 10, 'russia': 10, '俄罗斯': 10,
  'in': 11, 'india': 11, '印度': 11,
  'tr': 12, 'turkey': 12, '土耳其': 12,
  'br': 13, 'brazil': 13, '巴西': 13,
  'my': 14, 'malaysia': 14, '马来西亚': 14,
  'th': 15, 'thailand': 15, '泰国': 15,
  'vn': 16, 'vietnam': 16, '越南': 16,
  'ph': 17, 'philippines': 17, '菲律宾': 17,
};

/// 信息类节点（订阅里常见的置顶项），排在所有真实节点之前
const _infoKeys = [
  '剩余流量', '剩余', '到期', '过期', '套餐', '官网', '订阅', '重置',
  '距离下次', '流量', 'traffic', 'expire', 'website', '剩余流量：',
];

/// 规则/策略类分组的特征词，排在区域分组之前
const _ruleKeys = [
  '规则', 'rule', '全球', '手动', 'manual', '选择', 'select', '自动',
  'auto', '故障', 'fallback', '负载', 'load', 'url-test', '延迟', '测速',
  'final', '兜底', '其它', '其他', '广告', 'adblock', 'direct', 'reject',
  '直连', '拒绝',
];

int _regionRank(String name) {
  final lower = name.toLowerCase();
  var best = 999;
  _regions.forEach((key, rank) {
    if (lower.contains(key) && rank < best) best = rank;
  });
  return best;
}

/// 分组排序权重：规则类 0，区域类 100+区域序号，其他 900
int groupRank(String name) {
  final lower = name.toLowerCase();
  if (_ruleKeys.any(lower.contains)) return 0;
  final r = _regionRank(name);
  if (r < 999) return 100 + r;
  return 900;
}

/// 节点排序权重：信息节点 0，区域节点 100+区域序号，其他 900
int nodeRank(String name) {
  final lower = name.toLowerCase();
  if (_infoKeys.any(lower.contains)) return 0;
  final r = _regionRank(name);
  if (r < 999) return 100 + r;
  return 900;
}

/// 按权重稳定排序（同权重保持原有顺序）
List<T> sortByRank<T>(List<T> items, int Function(T) rankOf) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final d = rankOf(a.$2).compareTo(rankOf(b.$2));
    return d != 0 ? d : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// 数值格式化
String fmtBytes(num bytes, {int digits = 1}) {
  if (bytes < 0) return '--';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final s = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(digits);
  return '$s ${units[i]}';
}

String fmtSpeed(num bytesPerSec) => '${fmtBytes(bytesPerSec)}/s';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String fmtAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s 前';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m 前';
  return '${diff.inHours}h 前';
}

String two(int v) => v.toString().padLeft(2, '0');

String fmtClock(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

/// 把网络异常翻译成人话
String describeError(Object e) {
  final text = e.toString();
  if (text.contains('status code of 401') || text.contains('401')) {
    return 'HTTP 401：内核要求密钥。请在 设置 → 连接 → 密钥 Secret 里填入 mihomo 配置中的 secret；'
        '如果内核没设 secret，这一栏留空即可。';
  }
  if (text.contains('403')) {
    return 'HTTP 403：密钥被拒绝，检查 Secret 是否多打了空格或引号。';
  }
  if (text.contains('Connection refused')) return '连接被拒绝，内核没在监听这个端口';
  if (text.contains('timed out') || text.contains('timeout')) {
    return '连接超时，检查地址和局域网访问';
  }
  if (text.contains('SocketException')) return '网络不可达，检查 IP 和端口';
  if (text.contains('HandshakeException')) return 'TLS 握手失败，https 地址是否正确';
  if (text.length > 120) return text.substring(0, 120);
  return text;
}

import 'dart:io';

/// 取第一个非回环 IPv4 地址（内网 IP）
Future<String?> localIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final itf in interfaces) {
      for (final addr in itf.addresses) {
        if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
          return addr.address;
        }
      }
    }
  } catch (_) {}
  return null;
}


/// 返回 (IPv4 地址, 网卡名)
Future<(String, String)?> localNetworkInfo() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final itf in interfaces) {
      for (final addr in itf.addresses) {
        if (!addr.isLoopback && !addr.address.startsWith('169.254.')) {
          return (addr.address, itf.name);
        }
      }
    }
  } catch (_) {}
  return null;
}

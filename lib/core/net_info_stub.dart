/// 非 IO 平台没有本地网卡信息
Future<String?> localIpv4() async => null;

Future<(String, String)?> localNetworkInfo() async => null;

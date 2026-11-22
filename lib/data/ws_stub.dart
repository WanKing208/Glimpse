import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel openSocket(Uri uri, {Map<String, String> headers = const {}}) {
  throw UnsupportedError('WebSocket 不支持当前平台');
}

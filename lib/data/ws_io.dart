import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel openSocket(Uri uri, {Map<String, String> headers = const {}}) {
  return IOWebSocketChannel.connect(uri, headers: headers);
}

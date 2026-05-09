import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import 'dart:convert';

class SignalingService {
  WebSocketChannel? _channel;
  String? _userId;
  bool _isConnected = false;

  StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  void connect(String userId, String wsUrl) {
    _userId = userId;
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _isConnected = true;

    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          _messageController.add(data);
        } catch (e) {
          print('JSON decode error: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        _isConnected = false;
      },
      onDone: () {
        print('WebSocket closed');
        _isConnected = false;
      },
    );

    _send({'type': 'register', 'userId': userId});
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      print('Cannot send, WebSocket not connected');
    }
  }

  void sendOffer(String targetId, Map<String, dynamic> offer) {
    _send({'type': 'offer', 'targetId': targetId, 'offer': offer});
  }

  void sendAnswer(String targetId, Map<String, dynamic> answer) {
    _send({'type': 'answer', 'targetId': targetId, 'answer': answer});
  }

  void sendIceCandidate(String targetId, Map<String, dynamic> candidate) {
    _send({'type': 'ice-candidate', 'targetId': targetId, 'candidate': candidate});
  }

  // Добавленный метод для завершения звонка
  void sendCallEnd(String targetId) {
    _send({'type': 'call-ended', 'targetId': targetId});
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close(status.normalClosure);
    _channel = null;
  }

  bool get isConnected => _isConnected;

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
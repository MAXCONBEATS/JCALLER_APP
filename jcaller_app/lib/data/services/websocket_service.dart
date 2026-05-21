import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:async';
import 'dart:convert';

class SignalingService {
  IOWebSocketChannel? _channel;
  String? _userId;
  String? _wsUrl;
  bool _isConnected = false;
  bool _disposed = false;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  StreamSubscription? _streamSubscription;

  StreamController<Map<String, dynamic>>? _messageController;

  Stream<Map<String, dynamic>> get onMessage {
    _ensureMessageController();
    return _messageController!.stream;
  }

  void _ensureMessageController() {
    if (_messageController == null || _messageController!.isClosed) {
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
    }
  }

  Future<void> connect(String userId, String wsUrl) async {
    _disposed = false;
    _manualDisconnect = false;
    _userId = userId;
    _wsUrl = wsUrl;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _manualDisconnect) return;

    _reconnectTimer?.cancel();
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    try {
      await _channel?.sink.close(status.goingAway);
    } catch (_) {}
    _channel = null;
    _isConnected = false;

    try {
      _ensureMessageController();
      _channel = IOWebSocketChannel.connect(Uri.parse(_wsUrl!));
      await _channel!.ready;
      _isConnected = true;

      _streamSubscription = _channel!.stream.listen(
        (raw) {
          if (_messageController == null || _messageController!.isClosed) return;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            _messageController!.add(data);
          } catch (e) {
            print('JSON decode error: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _send({'type': 'register', 'userId': _userId});
    } catch (e) {
      print('WebSocket connect failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _disposed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      if (_manualDisconnect || _disposed) return;
      print('Attempting to reconnect WebSocket...');
      if (_userId != null && _wsUrl != null) {
        _doConnect();
      }
    });
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
    _send({
      'type': 'ice-candidate',
      'targetId': targetId,
      'candidate': candidate,
    });
  }

  void sendCallEnd(String targetId) {
    _send({'type': 'call-ended', 'targetId': targetId});
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _channel?.sink.close(status.normalClosure);
    } catch (_) {}
    _channel = null;
  }

  bool get isConnected => _isConnected;

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageController?.close();
    _messageController = null;
  }
}

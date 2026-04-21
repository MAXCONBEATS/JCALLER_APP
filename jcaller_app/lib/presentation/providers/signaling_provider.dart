import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';
import 'package:jcaller_app/presentation/providers/online_users_provider.dart';

part 'signaling_provider.g.dart';

@riverpod
class SignalingServiceNotifier extends _$SignalingServiceNotifier {
  SignalingService? _service;
  String? _userId;

  @override
  SignalingService? build() => null; // изначально нет соединения

  Future<void> connect(String userId, String wsUrl) async {
    if (_service != null) return;
    _userId = userId;
    _service = SignalingService();
    _service!.connect(userId, wsUrl);
    state = _service;

    _service!.onMessage.listen((message) {
      _handleSignalingMessage(message);
    });
  }

  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    switch (type) {
      case 'users-online':
        final onlineUsers = List<String>.from(message['users'] ?? []);
        ref.read(onlineUsersProvider.notifier).update(onlineUsers);
        break;
      case 'incoming-call':
        // TODO: показать диалог входящего звонка
        print('Incoming call from ${message['senderId']}');
        break;
      case 'offer':
        // TODO: передать в CallManager
        print('Received offer from ${message['from']}');
        break;
      case 'answer':
        print('Received answer from ${message['from']}');
        break;
      case 'ice-candidate':
        print('Received ICE candidate');
        break;
      default:
        print('Unhandled message type: $type');
    }
  }

  void sendOffer(String targetId, Map<String, dynamic> offer) {
    _service?.sendOffer(targetId, offer);
  }

  void sendAnswer(String targetId, Map<String, dynamic> answer) {
    _service?.sendAnswer(targetId, answer);
  }

  void sendIceCandidate(String targetId, Map<String, dynamic> candidate) {
    _service?.sendIceCandidate(targetId, candidate);
  }

  Future<void> disconnect() async {
    if (_service != null) {
      _service!.dispose();
      _service = null;
    }
    state = null;
  }

  bool get isConnected => _service != null && _service!.isConnected;
}
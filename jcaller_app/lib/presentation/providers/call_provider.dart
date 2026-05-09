import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';
import 'package:jcaller_app/webrtc/call_manager.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';
import 'package:jcaller_app/presentation/providers/signaling_provider.dart';

part 'call_provider.g.dart';

@riverpod
class CallManagerNotifier extends _$CallManagerNotifier {
  @override
  CallManager? build() => null;

  Future<void> initialize(String myUserId) async {
    final signaling = ref.read(signalingServiceNotifierProvider);
    if (signaling == null) throw Exception('Signaling not connected');
    final manager = CallManager(signaling, myUserId);
    state = manager;

    // Подписываемся на входящие звонки – далее можно использовать глобальный ключ навигатора
    manager.onIncomingCall.listen((offerData) {
      _showIncomingCallDialog(offerData);
    });
  }

  void _showIncomingCallDialog(Map<String, dynamic> offerData) {
    // Здесь можно отобразить диалог, используя контекст приложения
    // Например, через глобальный navigatorKey
  }

  void startCall(String remoteUserId) {
    state?.startCall(remoteUserId);
  }

  void acceptCall(Map<String, dynamic> offerData, String fromUserId) {
    state?.acceptCall(offerData, fromUserId);
  }

  void rejectCall() {
    state?.rejectCall();
  }

  void endCall() {
    state?.endCall();
  }
}
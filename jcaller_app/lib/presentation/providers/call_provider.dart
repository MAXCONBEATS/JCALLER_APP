import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';
import 'package:jcaller_app/presentation/providers/signaling_provider.dart';
import 'package:jcaller_app/webrtc/call_manager.dart';

part 'call_provider.g.dart';

final pendingIncomingCallProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

@Riverpod(keepAlive: true)
class CallManagerNotifier extends _$CallManagerNotifier {
  @override
  CallManager? build() => null;

  SignalingService? get _signaling =>
      ref.read(signalingServiceNotifierProvider);

  void _ensureSignalingOnManager() {
    final signaling = _signaling;
    if (signaling != null && state != null) {
      state!.updateSignaling(signaling);
    }
  }

  Future<void> initialize(String myUserId) async {
    final signaling = _signaling;
    if (signaling == null || !signaling.isConnected) {
      throw Exception('Signaling not connected');
    }

    state?.dispose();
    state = CallManager(signaling);
  }

  void updateSignaling(SignalingService signaling) {
    state?.updateSignaling(signaling);
  }

  void clearPendingIncoming() {
    ref.read(pendingIncomingCallProvider.notifier).state = null;
  }

  Future<void> startCall(String remoteUserId) async {
    clearPendingIncoming();
    _ensureSignalingOnManager();
    await state?.startCall(remoteUserId);
  }

  Future<void> acceptCall(
      Map<String, dynamic> offerData, String fromUserId) async {
    clearPendingIncoming();
    _ensureSignalingOnManager();
    _ensureSignalingOnManager();
    await state?.acceptCall(offerData, fromUserId);

    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;

    nav.pushNamed(
      '/call',
      arguments: {
        'targetUserId': fromUserId,
        'targetUsername': fromUserId,
      },
    );
  }

  void rejectCall() {
    clearPendingIncoming();
    _ensureSignalingOnManager();
    state?.rejectCall();
  }

  void endCall() {
    clearPendingIncoming();
    _ensureSignalingOnManager();
    state?.endCall();
  }

  void disposeManager() {
    clearPendingIncoming();
    state?.dispose();
    state = null;
  }
}

/// Глобальный диалог входящего — работает на Home и поверх CallScreen.
void showGlobalIncomingCallDialog(
  WidgetRef ref,
  Map<String, dynamic> offerData,
) {
  ref.read(callManagerNotifierProvider.notifier).clearPendingIncoming();

  final fromUserId = offerData['from']?.toString();
  if (fromUserId == null) return;

  final navContext = rootNavigatorKey.currentContext;
  if (navContext == null) {
    debugPrint('❌ Cannot show incoming call: no navigator context');
    return;
  }

  showDialog(
    context: navContext,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Входящий звонок'),
      content: Text('Звонит: $fromUserId'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref.read(callManagerNotifierProvider.notifier).rejectCall();
          },
          child: const Text('Отклонить'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref
                .read(callManagerNotifierProvider.notifier)
                .acceptCall(offerData, fromUserId);
          },
          child: const Text('Принять'),
        ),
      ],
    ),
  );
}

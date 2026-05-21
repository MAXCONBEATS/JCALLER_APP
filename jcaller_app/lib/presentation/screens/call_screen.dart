import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';
import 'package:jcaller_app/webrtc/call_manager.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallScreen extends ConsumerWidget {
  final String targetUserId;
  final String targetUsername;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callManager = ref.watch(callManagerNotifierProvider);

    if (callManager == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Звонок $targetUsername')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<CallState>(
      stream: callManager.onStateChange,
      initialData: callManager.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? callManager.state;

        return Scaffold(
          appBar: AppBar(title: Text('Звонок $targetUsername')),
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: RTCVideoView(
                    callManager.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Статус: ${_statusText(state)}'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(callManagerNotifierProvider.notifier)
                            .endCall();
                        Navigator.pop(context);
                      },
                      child: const Text('Завершить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(CallState state) {
    switch (state) {
      case CallState.ringing:
        return 'Вызов...';
      case CallState.connecting:
        return 'Соединение...';
      case CallState.connected:
        return 'Разговор';
      case CallState.ended:
        return 'Завершён';
      default:
        return 'Ожидание';
    }
  }
}

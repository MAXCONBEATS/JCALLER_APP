import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';
import 'package:jcaller_app/webrtc/call_manager.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUsername;

  const CallScreen({super.key, required this.targetUserId, required this.targetUsername});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  late CallManagerNotifier _callManager;

  @override
  void initState() {
    super.initState();
    _callManager = ref.read(callManagerNotifierProvider.notifier);
  }

  @override
  Widget build(BuildContext context) {
    final callManager = ref.watch(callManagerNotifierProvider);
    final state = callManager?.state;

    return Scaffold(
      appBar: AppBar(title: Text('Звонок ${widget.targetUsername}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Статус: ${_statusText(state)}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _callManager.endCall();
                Navigator.pop(context);
              },
              child: const Text('Завершить'),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(CallState? state) {
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
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';
import 'package:jcaller_app/presentation/providers/online_users_provider.dart';

part 'signaling_provider.g.dart';

@Riverpod(keepAlive: true)
class SignalingServiceNotifier extends _$SignalingServiceNotifier {
  SignalingService? _service;
  String? _connectedUserId;
  bool _connecting = false;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  @override
  SignalingService? build() {
    ref.onDispose(() {
      disconnect();
    });
    return null;
  }

  Future<void> connect(String userId, String wsUrl) async {
    if (_connecting) return;

    if (_service != null &&
        _service!.isConnected &&
        _connectedUserId == userId) {
      await _syncCallManager(userId);
      return;
    }

    _connecting = true;
    try {
      if (_service != null) {
        await _messageSubscription?.cancel();
        await _service!.dispose();
        _service = null;
        state = null;
      }

      _service = SignalingService();
      await _service!.connect(userId, wsUrl);
      _connectedUserId = userId;
      state = _service;

      await _messageSubscription?.cancel();
      _messageSubscription = _service!.onMessage.listen(_handleSignalingMessage);

      await _syncCallManager(userId);
    } finally {
      _connecting = false;
    }
  }

  Future<void> _syncCallManager(String userId) async {
    final callNotifier = ref.read(callManagerNotifierProvider.notifier);
    if (ref.read(callManagerNotifierProvider) != null) {
      callNotifier.updateSignaling(_service!);
    } else {
      await callNotifier.initialize(userId);
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'users-online':
        final users = (message['users'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        ref.read(onlineUsersProvider.notifier).update(users);
        break;

      case 'offer':
        debugPrint('📞 WS offer from ${message['from']}');
        ref.read(pendingIncomingCallProvider.notifier).state = message;
        ref.read(callManagerNotifierProvider)?.handleSignalingMessage(message);
        break;

      case 'answer':
      case 'ice-candidate':
      case 'call-ended':
        ref.read(callManagerNotifierProvider)?.handleSignalingMessage(message);
        break;

      case 'registered':
        debugPrint('✅ Registered on signaling server');
        break;
    }
  }

  Future<void> disconnect() async {
    _connecting = false;
    _connectedUserId = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    if (_service != null) {
      await _service!.dispose();
      _service = null;
    }
    state = null;
  }

  bool get isConnected => _service?.isConnected ?? false;
}

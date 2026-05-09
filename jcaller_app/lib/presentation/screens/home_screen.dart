import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/core/models/user.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';
import 'package:jcaller_app/presentation/providers/current_user_provider.dart';
import 'package:jcaller_app/presentation/providers/signaling_provider.dart';
import 'package:jcaller_app/presentation/providers/online_users_provider.dart';
import 'package:jcaller_app/presentation/providers/users_provider.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _webSocketInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebSocket();
    });
  }

  Future<void> _initializeWebSocket() async {
    if (_webSocketInitialized) return;

    final token = ref.read(authNotifierProvider).valueOrNull;
    if (token == null) return;

    final currentUserState = ref.read(currentUserProvider);
    final user = currentUserState.valueOrNull;
    if (user == null) return;

    final wsUrl = 'ws://localhost:8080/ws/signal';
    final notifier = ref.read(signalingServiceNotifierProvider.notifier);
    await notifier.connect(user.id, wsUrl);
    _webSocketInitialized = true;
  }

  Future<void> _logout() async {
    final signaling = ref.read(signalingServiceNotifierProvider);
    if (signaling != null) {
      await ref.read(signalingServiceNotifierProvider.notifier).disconnect();
    }
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) {
  Navigator.of(context).pushReplacementNamed('/home');
}
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authNotifierProvider).valueOrNull;
    final usersAsync = ref.watch(usersListProvider);
    final onlineUsers = ref.watch(onlineUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    if (token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('JCaller - Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No users found'));
          final currentUser = currentUserAsync.valueOrNull;
          if (currentUser == null) return const Center(child: CircularProgressIndicator());
          final filtered = users.where((u) => u['id'] != currentUser.id).toList();
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final user = filtered[index];
              final userId = user['id'] as String;
              final isOnline = onlineUsers.contains(userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: Icon(isOnline ? Icons.circle : Icons.circle_outlined, color: Colors.white),
                ),
                title: Text(user['username'] ?? 'Unknown'),
                subtitle: Text(isOnline ? 'Online' : 'Offline'),
                trailing: IconButton(
  icon: const Icon(Icons.call),
  onPressed: () => _startCall(userId, user['username'] ?? 'User'),
),
              );
            },
          );
        },
      ),
    );
  }

  void _startCall(String targetUserId, String targetUsername) async {
  // Убеждаемся, что WebSocket готов
  if (!_webSocketInitialized) {
    await _initializeWebSocket();
  }
  final signaling = ref.read(signalingServiceNotifierProvider);
  if (signaling == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WebSocket not connected')),
    );
    return;
  }
  final currentUser = ref.read(currentUserProvider).valueOrNull;
  if (currentUser == null) return;
  
  final callManagerNotifier = ref.read(callManagerNotifierProvider.notifier);
  await callManagerNotifier.initialize(currentUser.id);
  callManagerNotifier.startCall(targetUserId);
  
  if (mounted) {
    Navigator.pushNamed(
      context,
      '/call',
      arguments: {
        'targetUserId': targetUserId,
        'targetUsername': targetUsername,
      },
    );
  }
}
}
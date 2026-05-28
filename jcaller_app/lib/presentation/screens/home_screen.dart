import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/core/config/server_config.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';
import 'package:jcaller_app/presentation/providers/current_user_provider.dart';
import 'package:jcaller_app/presentation/providers/signaling_provider.dart';
import 'package:jcaller_app/presentation/providers/online_users_provider.dart';
import 'package:jcaller_app/presentation/providers/users_provider.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';
import 'package:jcaller_app/webrtc/call_manager.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSignalingAndCalls();
    });
  }

  Future<void> _connectSignalingAndCalls() async {
    final token = ref.read(authNotifierProvider).valueOrNull;
    if (token == null) return;

    try {
      final user = await ref.read(currentUserProvider.future);
      final signalingNotifier =
          ref.read(signalingServiceNotifierProvider.notifier);

      if (!signalingNotifier.isConnected) {
        await signalingNotifier.connect(user.id, ServerConfig.wsSignalUrl);
      }

      await ref.read(callManagerNotifierProvider.notifier).initialize(user.id);
    } catch (e) {
      debugPrint('Signaling setup error: $e');
    }
  }

  Future<bool> _ensureSignalingReady() async {
    final signaling = ref.read(signalingServiceNotifierProvider);
    final notifier = ref.read(signalingServiceNotifierProvider.notifier);

    if (signaling != null && notifier.isConnected) return true;

    await _connectSignalingAndCalls();

    final updated = ref.read(signalingServiceNotifierProvider);
    return updated != null && notifier.isConnected;
  }

  Future<void> _logout() async {
    ref.read(callManagerNotifierProvider.notifier).disposeManager();
    await ref.read(signalingServiceNotifierProvider.notifier).disconnect();
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authNotifierProvider).valueOrNull;
    final usersAsync = ref.watch(usersListProvider);
    final onlineUsers = ref.watch(onlineUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    // Держим signaling и call manager живыми, пока открыт Home
    ref.watch(signalingServiceNotifierProvider);
    ref.watch(callManagerNotifierProvider);

    ref.listen(currentUserProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        _connectSignalingAndCalls();
      }
    });

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
        error: (err, _) {
          final message = err.toString();
          if (message.contains('сессия истекла')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(authNotifierProvider.notifier)
                  .logout(showMessage: false);
            });
            return const Center(
                child: Text('Сессия истекла. Перенаправление...'));
          }
          return Center(child: Text('Ошибка: $err'));
        },
        data: (users) {
          if (users.isEmpty) return const Center(child: Text('No users found'));
          final currentUser = currentUserAsync.valueOrNull;
          if (currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final currentUserId = currentUser.id.toString();
          final filtered = users
              .where((u) => (u['id']?.toString() ?? '') != currentUserId)
              .toList();
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final user = filtered[index];
              final userId = user['id'].toString();
              final isOnline = onlineUsers.contains(userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: Icon(
                    isOnline ? Icons.circle : Icons.circle_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(user['username'] ?? 'Unknown'),
                subtitle: Text(isOnline ? 'Online' : 'Offline'),
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () =>
                      _startCall(userId, user['username'] ?? 'User'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startCall(String targetUserId, String targetUsername) async {
    final ready = await _ensureSignalingReady();
    if (!ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebSocket not connected')),
        );
      }
      return;
    }

    final currentUser = await ref.read(currentUserProvider.future);
    final myId = currentUser.id.toString();
    if (targetUserId.toString() == myId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя звонить самому себе')),
        );
      }
      return;
    }

    final callNotifier = ref.read(callManagerNotifierProvider.notifier);
    final manager = ref.read(callManagerNotifierProvider);

    if (manager == null || manager.state != CallState.idle) {
      await callNotifier.initialize(currentUser.id);
    } else {
      callNotifier.updateSignaling(
        ref.read(signalingServiceNotifierProvider)!,
      );
    }
    await callNotifier.startCall(targetUserId);

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

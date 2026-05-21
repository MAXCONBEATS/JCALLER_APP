import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/presentation/screens/login_screen.dart';
import 'package:jcaller_app/presentation/screens/register_screen.dart';
import 'package:jcaller_app/presentation/screens/home_screen.dart';
import 'package:jcaller_app/presentation/screens/call_screen.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';
import 'package:jcaller_app/presentation/providers/call_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  runApp(const ProviderScope(child: JCallerApp()));
}

Future<void> requestPermissions() async {
  await [Permission.microphone].request();
}

class JCallerApp extends ConsumerWidget {
  const JCallerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(pendingIncomingCallProvider, (prev, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showGlobalIncomingCallDialog(ref, next);
      });
    });

    return MaterialApp(
      title: 'JCaller',
      theme: ThemeData.dark(),
      initialRoute: '/',
      navigatorKey: rootNavigatorKey,
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/call': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return CallScreen(
            targetUserId: args['targetUserId'],
            targetUsername: args['targetUsername'],
          );
        },
      },
    );
  }
}

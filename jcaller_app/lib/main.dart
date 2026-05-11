import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/presentation/screens/login_screen.dart';
import 'package:jcaller_app/presentation/screens/register_screen.dart';
import 'package:jcaller_app/presentation/screens/home_screen.dart';
import 'package:jcaller_app/presentation/screens/call_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jcaller_app/presentation/providers/auth_provider.dart';

void main() async {
  // Запрос разрешений при старте приложения
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  runApp(const ProviderScope(child: JCallerApp()));
}

Future<void> requestPermissions() async {
  await [Permission.microphone].request();
}

class JCallerApp extends StatelessWidget {
  const JCallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JCaller',
      theme: ThemeData.dark(),
      initialRoute: '/',
      navigatorKey: rootNavigatorKey, // глобальный ключ из auth_provider.dart
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
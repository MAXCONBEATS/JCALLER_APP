import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jcaller_app/presentation/screens/login_screen.dart';
import 'package:jcaller_app/presentation/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: JCallerApp()));
}

class JCallerApp extends StatelessWidget {
  const JCallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JCaller',
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
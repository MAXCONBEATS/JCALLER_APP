import 'dart:io';

/// Адрес сервера в локальной сети.
/// Для эмулятора Android: 10.0.2.2
/// Для реального телефона: IP вашего ПК в LAN (например 192.168.1.10)
const String kServerHost = '192.168.0.10';

class ServerConfig {
  static String get host => Platform.isAndroid ? kServerHost : 'localhost';

  static String get apiBaseUrl => 'http://$host:8081';
  static String get wsSignalUrl => 'ws://$host:8080/ws/signal';
}

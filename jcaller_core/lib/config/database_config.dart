import 'dart:io';
import 'package:dotenv/dotenv.dart';

class DatabaseConfig {
  static late final DotEnv _dotEnv;
  
  static Future<void> initialize() async {
    _dotEnv = DotEnv(includePlatformEnvironment: true)..load();
  }
  
  static String get host {
    final value = _dotEnv['DB_HOST'] ?? 'localhost';
    // Убираем кавычки если они есть
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    if (value.startsWith("'") && value.endsWith("'")) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
  
  static int get port => int.tryParse(_dotEnv['DB_PORT'] ?? '1433') ?? 1433;
  static String get database => _dotEnv['DB_NAME'] ?? 'JCallerDB';
  static String get username => _dotEnv['DB_USER'] ?? '';
  static String get password => _dotEnv['DB_PASSWORD'] ?? '';
  static bool get trustCertificate => _dotEnv['DB_TRUST_CERT'] == 'true';
  static bool get useWindowsAuth => _dotEnv['DB_INTEGRATED_SECURITY'] == 'true';
  
  static bool get isNamedPipe => host.startsWith(r'np:') || host.contains(r'\\.\pipe\');
  
  static void printConfig() {
    print('📊 Database Configuration:');
    print('  Host: $host');
    print('  Port: ${isNamedPipe ? "named pipe" : port}');
    print('  Database: $database');
    print('  Windows Auth: $useWindowsAuth');
    print('  Connection type: ${isNamedPipe ? "Named Pipe" : "TCP/IP"}');
  }
}
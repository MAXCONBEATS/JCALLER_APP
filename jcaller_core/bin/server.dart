import 'dart:io';
import 'package:jcaller_core/server/jcaller_server.dart';
import 'package:jcaller_core/api/user_api.dart';
import 'package:jcaller_core/repositories/sqlite_users_repository.dart';

void main(List<String> arguments) async {
  print('🚀 Starting JCaller servers with SQLite...\n');
  
  try {
    // Создаем SQLite репозиторий
    final repository = SqliteUsersRepository();
    await repository.init();
    
    // Запускаем UserApi на порту 8081
    final userApi = UserApi(repository);
    Future(() async {
      try {
        await userApi.run();
      } catch (e) {
        print('❌ User API error: $e');
      }
    });
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Запускаем основной сервер на порту 8080
    final mainServer = JCallerServer(repository);
    await mainServer.start(port: 8080);
    
    print('''
╔══════════════════════════════════════════════════════════════╗
║  🚀 Servers started successfully! (SQLite)                   ║
╠══════════════════════════════════════════════════════════════╣
║  User API:     http://localhost:8081                         ║
║  Main Server:  http://localhost:8080                         ║
║  WebSocket:    ws://localhost:8080/ws/signal                 ║
║  Database:     SQLite (jcaller.db)                           ║
╚══════════════════════════════════════════════════════════════╝

Press Ctrl+C to stop
''');
    
    // Обработка Ctrl+C
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n🛑 Shutting down gracefully...');
      
      try {
        await mainServer.stop();
        await repository.dispose();
        print('✅ Servers stopped');
        print('👋 Goodbye!');
      } catch (e) {
        print('❌ Error during shutdown: $e');
      } finally {
        exit(0);
      }
    });
    
  } catch (e, stackTrace) {
    print('❌ Failed to start servers: $e');
    print(stackTrace);
    exit(1);
  }
}
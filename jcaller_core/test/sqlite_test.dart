import 'package:jcaller_core/repositories/sqlite_users_repository.dart';

void main() async {
  print('🧪 Testing SQLite Repository\n');
  
  try {
    final repo = SqliteUsersRepository();
    await repo.init();
    print('✅ Database initialized');
    
    // Создаем пользователя
    try {
      final user = await repo.createUser('test_user', 'password123');
      print('✅ Created user: ${user.username} (${user.id})');
    } catch (e) {
      print('ℹ️ User may already exist: $e');
    }
    
    // Получаем всех пользователей
    final users = await repo.getUsers();
    print('✅ Found ${users.length} users:');
    for (var user in users) {
      print('   - ${user.username}');
    }
    
    // Тестируем аутентификацию
    final authUser = await repo.authenticate('test_user', 'password123');
    if (authUser != null) {
      print('✅ Authentication successful');
    } else {
      print('❌ Authentication failed');
    }
    
    await repo.dispose();
    print('✅ Database closed');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
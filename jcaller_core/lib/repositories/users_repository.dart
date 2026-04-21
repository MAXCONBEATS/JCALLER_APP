import 'dart:async';
import 'package:jcaller_core/models/user.dart';

abstract interface class UsersRepository {
  Future<void> init();
  Future<void> dispose();
  Future<List<User>> getUsers();
  Future<User?> getUser(String id);
  Future<User?> getUserByUsername(String username);
  Future<User> createUser(String username, String password);
  Future<User?> authenticate(String username, String password);
  Future<void> deleteUser(String id);
  Future<User> updateUser(String id, User user);
}
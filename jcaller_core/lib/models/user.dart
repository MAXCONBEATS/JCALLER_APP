import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String password;
  final DateTime createdAt;
  
  // Добавим поле для онлайн статуса (не сохраняется в БД)
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isOnline = false;
  
  User({
    required this.id,
    required this.username,
    required this.password,
    required this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  // Безопасное копирование с изменениями
  User copyWith({
    String? id,
    String? username,
    String? password,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
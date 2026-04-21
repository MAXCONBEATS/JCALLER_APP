class User {
  final String id;
  final String username;
  final DateTime createdAt;
  final bool isOnline; // для клиентского UI

  User({
    required this.id,
    required this.username,
    required this.createdAt,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline,
    };
  }
}
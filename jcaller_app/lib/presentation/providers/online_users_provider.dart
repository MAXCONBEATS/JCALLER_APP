import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'online_users_provider.g.dart';

@riverpod
class OnlineUsers extends _$OnlineUsers {
  @override
  List<String> build() => [];

  void update(List<String> users) {
    state = users;
  }
}
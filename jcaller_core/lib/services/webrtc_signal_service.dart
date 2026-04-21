import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class WebRTCSignalService {
  final Map<String, WebSocketChannel> _connectedUsers = {};
  final Map<String, List<Map<String, dynamic>>> _pendingOffers = {};
  
  Handler get handler {
    final router = Router();
    
    router.mount('/signal', webSocketHandler((WebSocketChannel channel, {String? protocol}) {
      _handleSignalConnection(channel);
    }));
    
    return router;
  }
  
  void _handleSignalConnection(WebSocketChannel channel) {
    String? userId;
    
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message as String);
        
        switch (data['type']) {
          case 'register':
            userId = data['userId'];
            _connectedUsers[userId!] = channel;
            
            // Отправляем ожидающие предложения
            if (_pendingOffers.containsKey(userId)) {
              for (var offer in _pendingOffers[userId]!) {
                channel.sink.add(jsonEncode(offer));
              }
              _pendingOffers.remove(userId);
            }
            
            // Уведомляем других пользователей
            _broadcastUserList();
            break;
            
          case 'offer':
            final targetUserId = data['targetUserId'];
            final offer = data['offer'];
            
            if (_connectedUsers.containsKey(targetUserId)) {
              // Пользователь онлайн - отправляем сразу
              _connectedUsers[targetUserId]!.sink.add(jsonEncode({
                'type': 'offer',
                'fromUserId': userId,
                'offer': offer,
              }));
            } else {
              // Сохраняем для офлайн пользователя
              _pendingOffers.putIfAbsent(targetUserId, () => []);
              _pendingOffers[targetUserId]!.add({
                'type': 'offer',
                'fromUserId': userId,
                'offer': offer,
              });
            }
            break;
            
          case 'answer':
            final targetUserId = data['targetUserId'];
            final answer = data['answer'];
            
            if (_connectedUsers.containsKey(targetUserId)) {
              _connectedUsers[targetUserId]!.sink.add(jsonEncode({
                'type': 'answer',
                'fromUserId': userId,
                'answer': answer,
              }));
            }
            break;
            
          case 'ice-candidate':
            final targetUserId = data['targetUserId'];
            final candidate = data['candidate'];
            
            if (_connectedUsers.containsKey(targetUserId)) {
              _connectedUsers[targetUserId]!.sink.add(jsonEncode({
                'type': 'ice-candidate',
                'fromUserId': userId,
                'candidate': candidate,
              }));
            }
            break;
            
          case 'end-call':
            final targetUserId = data['targetUserId'];
            
            if (_connectedUsers.containsKey(targetUserId)) {
              _connectedUsers[targetUserId]!.sink.add(jsonEncode({
                'type': 'call-ended',
                'fromUserId': userId,
              }));
            }
            break;
        }
      },
      onDone: () {
        if (userId != null) {
          _connectedUsers.remove(userId);
          _broadcastUserList();
        }
      },
    );
  }
  
  void _broadcastUserList() {
    final userList = _connectedUsers.keys.toList();
    
    for (var entry in _connectedUsers.entries) {
      entry.value.sink.add(jsonEncode({
        'type': 'user-list',
        'users': userList.where((id) => id != entry.key).toList(),
      }));
    }
  }
}
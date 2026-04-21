import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:jcaller_core/models/call_request.dart';
import 'package:jcaller_core/models/calling_session.dart';
import 'package:jcaller_core/repositories/users_repository.dart';
import 'package:shelf_swagger_ui/shelf_swagger_ui.dart';

class JCallerServer {
  late HttpServer _server;
  final UsersRepository _userRepository;
  final Map<String, WebSocketChannel> _signalHandlers = {};
  final Map<String, List<CallRequest>> _pendingRequests = {};
  final Map<String, CallingSession> _activeSessions = {};
  
  JCallerServer(this._userRepository);
  
  Future<void> start({int port = 8080}) async {
    
    final app = Router();
    final swaggerHandler = SwaggerUI('specs/swagger_calls.yaml', title: 'JCaller Calls API');
app.mount('/docs', swaggerHandler);
    
    // Health check
    app.get('/health', _healthCheck);
    
    // WebSocket for signaling
    app.mount('/ws/signal', webSocketHandler((WebSocketChannel channel, {String? protocol}) {
      _handleSignalConnection(channel);
    }));
    
    // Call management endpoints
    app.post('/api/calls/request', _createCallRequest);
    app.get('/api/calls/requests/<userId>', _getPendingRequests);
    app.post('/api/calls/accept/<requestId>', _acceptCall);
    app.post('/api/calls/reject/<requestId>', _rejectCall);
    app.post('/api/calls/end/<sessionId>', _endCall);
    
    // Get online users (интеграция с UserApi)
    app.get('/api/online-users', _getOnlineUsers);
    
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_addCorsHeaders())
        .addHandler(app);
    
    _server = await serve(handler, InternetAddress.anyIPv4, port);
    developer.log('JCallerServer running on http://${_server.address.host}:${_server.port}');
  }
  
  Middleware _addCorsHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(null, headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
          });
        }
        
        final response = await innerHandler(request);
        return response.change(headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
        });
      };
    };
  }
  
  // WebRTC Signaling
  void _handleSignalConnection(WebSocketChannel channel) {
    String? userId;
    
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message as String);
        
        switch (data['type']) {
          case 'register':
            userId = data['userId'];
            _signalHandlers[userId!] = channel;
            developer.log('User $userId registered for signaling');
            _broadcastUserList();
            break;
            
          case 'offer':
            final targetId = data['targetId'];
            if (_signalHandlers.containsKey(targetId)) {
              _signalHandlers[targetId]!.sink.add(jsonEncode({
                'type': 'offer',
                'from': userId,
                'offer': data['offer'],
              }));
            }
            break;
            
          case 'answer':
            final targetId = data['targetId'];
            if (_signalHandlers.containsKey(targetId)) {
              _signalHandlers[targetId]!.sink.add(jsonEncode({
                'type': 'answer',
                'from': userId,
                'answer': data['answer'],
              }));
            }
            break;
            
          case 'ice-candidate':
            final targetId = data['targetId'];
            if (_signalHandlers.containsKey(targetId)) {
              _signalHandlers[targetId]!.sink.add(jsonEncode({
                'type': 'ice-candidate',
                'from': userId,
                'candidate': data['candidate'],
              }));
            }
            break;
        }
      },
      onDone: () {
        if (userId != null) {
          _signalHandlers.remove(userId);
          _broadcastUserList();
        }
      },
    );
  }
  
  void _broadcastUserList() {
    final onlineUsers = _signalHandlers.keys.toList();
    
    for (var entry in _signalHandlers.entries) {
      entry.value.sink.add(jsonEncode({
        'type': 'users-online',
        'users': onlineUsers.where((id) => id != entry.key).toList(),
      }));
    }
  }
  
  // Health check
  Response _healthCheck(Request request) {
    return Response.ok(
      jsonEncode({'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  // Get online users
  Future<Response> _getOnlineUsers(Request request) async {
    final onlineIds = _signalHandlers.keys.toList();
    final users = <Map<String, dynamic>>[];
    
    for (final id in onlineIds) {
      final user = await _userRepository.getUser(id);
      if (user != null) {
        final userJson = user.toJson();
        userJson.remove('password');
        users.add(userJson);
      }
    }
    
    return Response.ok(
      jsonEncode(users),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  // Call management endpoints
  Future<Response> _createCallRequest(Request request) async {
    try {
      final payload = await request.readAsString();
      final json = jsonDecode(payload);
      
      final callRequest = CallRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: json['senderId'],
        recipientId: json['recipientId'],
        createdAt: DateTime.now(),
        status: 'pending',
      );
      
      _pendingRequests.putIfAbsent(callRequest.recipientId, () => []);
      _pendingRequests[callRequest.recipientId]!.add(callRequest);
      
      // Уведомляем получателя через WebSocket если онлайн
      if (_signalHandlers.containsKey(callRequest.recipientId)) {
        _signalHandlers[callRequest.recipientId]!.sink.add(jsonEncode({
          'type': 'incoming-call',
          'request': callRequest.toJson(),
        }));
      }
      
      return Response.ok(
        jsonEncode(callRequest.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'error': e.toString()}));
    }
  }
  
  Future<Response> _getPendingRequests(Request request, String userId) async {
    final requests = _pendingRequests[userId] ?? [];
    return Response.ok(
      jsonEncode(requests.map((r) => r.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  Future<Response> _acceptCall(Request request, String requestId) async {
    for (var entry in _pendingRequests.entries) {
      final requestIndex = entry.value.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        final callRequest = entry.value[requestIndex];
        
        final session = CallingSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          callerId: callRequest.senderId,
          recipientId: callRequest.recipientId,
          startTime: DateTime.now(),
          durationSeconds: 0,
          status: CallStatus.connected,
        );
        
        _activeSessions[session.id] = session;
        _pendingRequests[entry.key]!.removeAt(requestIndex);
        
        if (_signalHandlers.containsKey(callRequest.senderId)) {
          _signalHandlers[callRequest.senderId]!.sink.add(jsonEncode({
            'type': 'call-accepted',
            'session': session.toJson(),
          }));
        }
        
        return Response.ok(
          jsonEncode(session.toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    
    return Response.notFound(jsonEncode({'error': 'Request not found'}));
  }
  
  Future<Response> _rejectCall(Request request, String requestId) async {
    for (var entry in _pendingRequests.entries) {
      final requestIndex = entry.value.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        final callRequest = entry.value[requestIndex];
        _pendingRequests[entry.key]!.removeAt(requestIndex);
        
        if (_signalHandlers.containsKey(callRequest.senderId)) {
          _signalHandlers[callRequest.senderId]!.sink.add(jsonEncode({
            'type': 'call-rejected',
            'requestId': requestId,
          }));
        }
        
        return Response.ok(jsonEncode({'message': 'Call rejected'}));
      }
    }
    
    return Response.notFound(jsonEncode({'error': 'Request not found'}));
  }
  
  Future<Response> _endCall(Request request, String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      return Response.notFound(jsonEncode({'error': 'Session not found'}));
    }
    
    final endedSession = CallingSession(
      id: session.id,
      callerId: session.callerId,
      recipientId: session.recipientId,
      startTime: session.startTime,
      endTime: DateTime.now(),
      durationSeconds: DateTime.now().difference(session.startTime).inSeconds,
      status: CallStatus.ended,
    );
    
    _activeSessions.remove(sessionId);
    
    return Response.ok(
      jsonEncode(endedSession.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }
  
  Future<void> stop() async {
    await _userRepository.dispose();
    await _server.close();
  }
}
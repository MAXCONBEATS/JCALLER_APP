import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';

enum CallState {
  idle,
  ringing,
  connecting,
  connected,
  ended,
}

class CallManager {
  final SignalingService _signaling;
  final String _myUserId;
  String? _remoteUserId;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  CallState _state = CallState.idle;

  final _stateController = StreamController<CallState>.broadcast();
  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();

  CallManager(this._signaling, this._myUserId) {
    _signaling.onMessage.listen(_handleSignalingMessage);
  }

  CallState get state => _state;
  Stream<CallState> get onStateChange => _stateController.stream;
  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;

  void _setState(CallState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // Инициировать звонок
  Future<void> startCall(String remoteUserId) async {
    if (_state != CallState.idle) return;
    _remoteUserId = remoteUserId;
    _setState(CallState.ringing);

    await _initPeerConnection();
    await _setupLocalStream();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _signaling.sendOffer(remoteUserId, offer.toMap());
  }

  // Ответить на входящий звонок
  Future<void> acceptCall(Map<String, dynamic> offerData, String fromUserId) async {
    if (_state != CallState.idle) return;
    _remoteUserId = fromUserId;
    _setState(CallState.connecting);

    await _initPeerConnection();
    await _setupLocalStream();

    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection!.setRemoteDescription(offer);
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _signaling.sendAnswer(fromUserId, answer.toMap());
    _setState(CallState.connected);
  }

  // Отклонить звонок (исходящий или входящий)
  void rejectCall() {
    _cleanup();
    _setState(CallState.ended);
  }

  // Завершить активный звонок
  void endCall() {
    if (_remoteUserId != null) {
      _signaling.sendCallEnd(_remoteUserId!);
    }
    _cleanup();
    _setState(CallState.ended);
  }

  Future<void> _initPeerConnection() async {
    final config = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
  'sdpSemantics': 'plan-b',
};
    _peerConnection = await createPeerConnection(config);
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remoteUserId != null && candidate != null) {
        _signaling.sendIceCandidate(_remoteUserId!, candidate.toMap());
      }
    };
    _peerConnection!.onTrack = (event) {
      // Можно передать удалённый трек в UI
    };
    _peerConnection!.onIceConnectionState = (state) {
      print('ICE connection state: $state');
    };
  }

  Future<void> _setupLocalStream() async {
  try {
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    print('✅ Local stream added');
    _peerConnection?.addStream(_localStream!);
  } catch (e) {
    print('❌ Error getting microphone: $e');
  }
}

  void _handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    switch (type) {
      case 'offer':
        if (_state == CallState.idle) {
          _incomingCallController.add(message);
        }
        break;
      case 'answer':
        if (_state == CallState.ringing || _state == CallState.connecting) {
          _handleAnswer(message);
        }
        break;
      case 'ice-candidate':
        if (_peerConnection != null) {
          final candidate = RTCIceCandidate(
            message['candidate']['candidate'],
            message['candidate']['sdpMid'],
            message['candidate']['sdpMLineIndex'],
          );
          _peerConnection?.addCandidate(candidate);
        }
        break;
      case 'call-ended':
        _cleanup();
        _setState(CallState.ended);
        break;
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    final answer = RTCSessionDescription(message['answer']['sdp'], message['answer']['type']);
    await _peerConnection?.setRemoteDescription(answer);
    _setState(CallState.connected);
  }

  void _cleanup() {
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _remoteUserId = null;
  }

  void dispose() {
    _cleanup();
    _stateController.close();
    _incomingCallController.close();
  }
}
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';

enum CallState {
  idle,
  ringing,
  connecting,
  connected,
  ended,
}

class CallManager {
  SignalingService _signaling;
  String? _remoteUserId;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteAudioStream;
  CallState _state = CallState.idle;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  final _stateController = StreamController<CallState>.broadcast();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  CallManager(this._signaling) {
    _initRenderer();
  }

  void updateSignaling(SignalingService signaling) {
    _signaling = signaling;
  }

  CallState get state => _state;

  /// Сразу отдаёт текущий статус, затем все изменения (важно для принявшего звонок).
  Stream<CallState> get onStateChange async* {
    yield _state;
    yield* _stateController.stream;
  }
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
  }

  void _setState(CallState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> startCall(String remoteUserId) async {
    if (_state != CallState.idle) {
      debugPrint('startCall ignored: state=$_state');
      return;
    }
    _remoteUserId = remoteUserId;
    _setState(CallState.ringing);

    await _initPeerConnection();
    await _setupLocalStream();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _signaling.sendOffer(remoteUserId, _sdpToMap(offer));
    debugPrint('📤 Offer sent to $remoteUserId');
  }

  Future<void> acceptCall(
      Map<String, dynamic> offerData, String fromUserId) async {
    if (_state != CallState.idle) {
      debugPrint('acceptCall ignored: state=$_state');
      return;
    }
    _remoteUserId = fromUserId;
    _setState(CallState.connecting);

    await _initPeerConnection();
    await _setupLocalStream();

    final offerMap =
        (offerData['offer'] as Map<String, dynamic>?) ?? offerData;
    final offer = RTCSessionDescription(
      offerMap['sdp'] as String,
      offerMap['type'] as String,
    );
    await _peerConnection!.setRemoteDescription(offer);
    await _flushPendingIceCandidates();

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _signaling.sendAnswer(fromUserId, _sdpToMap(answer));
    _setState(CallState.connected);
    debugPrint('📤 Answer sent to $fromUserId');
  }

  void rejectCall() {
    _notifyRemoteEnded();
    _cleanup();
    _setState(CallState.idle);
  }

  void endCall() {
    _notifyRemoteEnded();
    _cleanup();
    _setState(CallState.idle);
  }

  void _notifyRemoteEnded() {
    if (_remoteUserId != null) {
      _signaling.sendCallEnd(_remoteUserId!);
    }
  }

  Map<String, dynamic> _sdpToMap(RTCSessionDescription sdp) {
    return {'sdp': sdp.sdp, 'type': sdp.type};
  }

  Future<void> _initPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    final constraints = {
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };
    _peerConnection = await createPeerConnection(config, constraints);
    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
      ),
    );
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remoteUserId != null && candidate.candidate != null) {
        _signaling.sendIceCandidate(
          _remoteUserId!,
          {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        );
      }
    };
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams.first;
        debugPrint('Remote track received (stream-based)');
      } else if (event.track.kind == 'audio') {
        _attachTrackWithoutStream(event.track);
        debugPrint('Remote audio track received (track-only)');
      }
    };
    _peerConnection!.onIceConnectionState = (iceState) {
      debugPrint('ICE connection state: $iceState');
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        if (_state == CallState.ringing || _state == CallState.connecting) {
          _setState(CallState.connected);
        }
      }
    };
  }

  Future<void> _setupLocalStream() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission denied');
      }

      _localStream = await navigator.mediaDevices
          .getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
        },
        'video': false,
      });
      final audioTrack = _localStream!.getAudioTracks().first;
      _peerConnection!.addTrack(audioTrack, _localStream!);
      debugPrint('✅ Local audio track added');
    } catch (e) {
      debugPrint('❌ Error getting microphone: $e');
    }
  }

  /// Все WS-сообщения звонка приходят сюда из [SignalingServiceNotifier].
  void handleSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    switch (type) {
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _handleAnswerMessage(message);
        break;
      case 'ice-candidate':
        _handleIceCandidate(message);
        break;
      case 'call-ended':
        debugPrint('📴 Remote ended call');
        _cleanup();
        _setState(CallState.idle);
        break;
    }
  }

  void _handleOffer(Map<String, dynamic> message) {
    final from = message['from']?.toString();
    if (from == null) return;

    if (_state == CallState.idle) {
      debugPrint('📞 Incoming offer from $from (handled by UI)');
    } else {
      debugPrint('📞 Offer ignored (state=$_state), busy to $from');
      _signaling.sendCallEnd(from);
    }
  }

  Future<void> _handleAnswerMessage(Map<String, dynamic> message) async {
    if (_state != CallState.ringing && _state != CallState.connecting) {
      debugPrint('Answer ignored: state=$_state');
      return;
    }
    try {
      final answerMap = message['answer'] as Map<String, dynamic>;
      final answer = RTCSessionDescription(
        answerMap['sdp'] as String,
        answerMap['type'] as String,
      );
      await _peerConnection?.setRemoteDescription(answer);
      await _flushPendingIceCandidates();
      _setState(CallState.connected);
      debugPrint('✅ Answer applied from ${message['from']}');
    } catch (e) {
      debugPrint('❌ Failed to apply answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    final candidateMap = message['candidate'] as Map<String, dynamic>?;
    if (candidateMap == null) return;

    if (_peerConnection == null ||
        _state == CallState.idle ||
        _state == CallState.ended) {
      _pendingIceCandidates.add(candidateMap);
      return;
    }

    await _addIceCandidate(candidateMap);
  }

  Future<void> _flushPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final c in pending) {
      await _addIceCandidate(c);
    }
  }

  Future<void> _addIceCandidate(Map<String, dynamic> candidateMap) async {
    try {
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String?,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      debugPrint('ICE candidate error: $e');
    }
  }

  Future<void> _attachTrackWithoutStream(MediaStreamTrack track) async {
    _remoteAudioStream?.dispose();
    _remoteAudioStream = await createLocalMediaStream('remote-audio');
    _remoteAudioStream!.addTrack(track);
    _remoteRenderer.srcObject = _remoteAudioStream;
  }

  void _cleanup() {
    _pendingIceCandidates.clear();
    _localStream?.dispose();
    _localStream = null;
    _peerConnection?.close();
    _peerConnection = null;
    _remoteUserId = null;
    _remoteRenderer.srcObject = null;
    _remoteAudioStream?.dispose();
    _remoteAudioStream = null;
  }

  void dispose() {
    _cleanup();
    _stateController.close();
    _remoteRenderer.dispose();
  }
}

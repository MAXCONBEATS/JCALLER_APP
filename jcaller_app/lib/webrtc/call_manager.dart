import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:jcaller_app/data/services/websocket_service.dart';

class CallManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final SignalingService _signaling;
  final String myUserId;
  final String remoteUserId;

  CallManager(this._signaling, this.myUserId, this.remoteUserId) {
    _initListeners();
  }

  void _initListeners() {
    _signaling.onMessage.listen((message) {
      switch (message['type']) {
        case 'offer':
          _onOffer(message);
          break;
        case 'answer':
          _onAnswer(message);
          break;
        case 'ice-candidate':
          _onIceCandidate(message);
          break;
      }
    });
  }

  Future<void> startCall() async {
    await _initPeerConnection();
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _signaling.sendOffer(remoteUserId, offer.toMap());
  }

  Future<void> acceptCall(Map<String, dynamic> offer) async {
    await _initPeerConnection();
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _signaling.sendAnswer(remoteUserId, answer.toMap());
  }

  Future<void> _initPeerConnection() async {
    final config = {'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]};
    _peerConnection = await createPeerConnection(config);
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _peerConnection!.addStream(_localStream!);
    _peerConnection!.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(remoteUserId, candidate.toMap());
    };
  }

  void _onOffer(Map<String, dynamic> data) {
    // вызывается, когда приходит offer (для принимающей стороны)
    // нужно показать экран звонка и вызвать acceptCall
  }

  void _onAnswer(Map<String, dynamic> data) async {
    await _peerConnection?.setRemoteDescription(RTCSessionDescription(data['answer']['sdp'], data['answer']['type']));
  }

  void _onIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(data['candidate']['candidate'], data['candidate']['sdpMid'], data['candidate']['sdpMLineIndex']);
    await _peerConnection?.addCandidate(candidate);
  }

  void dispose() {
    _peerConnection?.close();
    _localStream?.dispose();
  }
}
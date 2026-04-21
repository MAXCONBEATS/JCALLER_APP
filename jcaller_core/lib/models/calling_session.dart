import 'package:json_annotation/json_annotation.dart';

part 'calling_session.g.dart';

@JsonSerializable()
class CallingSession {
  final String id;
  final String callerId;      // Кто инициировал звонок
  final String recipientId;    // Кому звонят (оставили как просили)
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final CallStatus status;
  
  CallingSession({
    required this.id,
    required this.callerId,
    required this.recipientId,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.status,
  });
  
  factory CallingSession.fromJson(Map<String, dynamic> json) => _$CallingSessionFromJson(json);
  Map<String, dynamic> toJson() => _$CallingSessionToJson(this);
}

enum CallStatus {
  ringing,    // Звонок идет
  connected,  // Соединение установлено
  ended,      // Завершен нормально
  missed,     // Пропущенный
  rejected    // Отклоненный
}
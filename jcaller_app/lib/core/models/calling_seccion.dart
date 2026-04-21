class CallingSession {
  final String id;
  final String callerId;
  final String recipientId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String status; // ringing, connected, ended, missed, rejected

  CallingSession({
    required this.id,
    required this.callerId,
    required this.recipientId,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.status,
  });

  factory CallingSession.fromJson(Map<String, dynamic> json) {
    return CallingSession(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      recipientId: json['recipientId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      durationSeconds: json['durationSeconds'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'recipientId': recipientId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'status': status,
    };
  }
}
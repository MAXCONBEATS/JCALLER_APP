class SignalMessage {
  final String type; // register, offer, answer, ice-candidate, incoming-call, call-accepted, etc.
  final String? userId; // для register
  final String? targetId;
  final Map<String, dynamic>? data; // offer/answer/candidate

  SignalMessage({
    required this.type,
    this.userId,
    this.targetId,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (userId != null) map['userId'] = userId;
    if (targetId != null) map['targetId'] = targetId;
    if (data != null) map.addAll(data!);
    return map;
  }

  factory SignalMessage.fromJson(Map<String, dynamic> json) {
    return SignalMessage(
      type: json['type'] as String,
      userId: json['userId'] as String?,
      targetId: json['targetId'] as String?,
      data: Map<String, dynamic>.from(json),
    );
  }
}
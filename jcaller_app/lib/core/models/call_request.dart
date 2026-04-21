class CallRequest {
  final String id;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;
  final String status; // pending, accepted, rejected, cancelled

  CallRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.status,
  });

  factory CallRequest.fromJson(Map<String, dynamic> json) {
    return CallRequest(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
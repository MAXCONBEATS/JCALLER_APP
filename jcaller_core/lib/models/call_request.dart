import 'package:json_annotation/json_annotation.dart';

part 'call_request.g.dart';

@JsonSerializable()
class CallRequest {
  final String id; // String для совместимости с User.id
  final String senderId;
  final String recipientId; // Исправлено опечатку
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled'
  
  CallRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.status,
  });
  
  factory CallRequest.fromJson(Map<String, dynamic> json) => _$CallRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CallRequestToJson(this);
}
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calling_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CallingSession _$CallingSessionFromJson(Map<String, dynamic> json) =>
    CallingSession(
      id: json['id'] as String,
      callerId: json['callerId'] as String,
      recipientId: json['recipientId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      status: $enumDecode(_$CallStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$CallingSessionToJson(CallingSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'callerId': instance.callerId,
      'recipientId': instance.recipientId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'durationSeconds': instance.durationSeconds,
      'status': _$CallStatusEnumMap[instance.status]!,
    };

const _$CallStatusEnumMap = {
  CallStatus.ringing: 'ringing',
  CallStatus.connected: 'connected',
  CallStatus.ended: 'ended',
  CallStatus.missed: 'missed',
  CallStatus.rejected: 'rejected',
};

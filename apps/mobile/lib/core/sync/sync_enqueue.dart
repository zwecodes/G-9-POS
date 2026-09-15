import 'dart:convert';

import '../database/daos/sync_queue_dao.dart';

Future<void> enqueueSyncEvent(
  SyncQueueDao queue, {
  required String id,
  required String eventType,
  required String deviceId,
  required String operatorId,
  required int createdAt,
  String? referenceId,
  Map<String, dynamic> extra = const {},
}) {
  final payload = <String, dynamic>{
    'id': id,
    'event_type': eventType,
    'device_id': deviceId,
    'operator_id': operatorId,
    'created_at': createdAt,
    'reference_id': referenceId,
    ...extra,
  };
  return queue.enqueue(
    id: id,
    eventType: eventType,
    payload: jsonEncode(payload),
    deviceId: deviceId,
    referenceId: referenceId,
    createdAt: createdAt,
  );
}

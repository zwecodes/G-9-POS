import 'dart:convert';

import '../database/app_database.dart';

/// SYNC-PROTOCOL.md §10 — 50 events, 5MB payload.
const int kSyncMaxEventsPerBatch = 50;
const int kSyncMaxPayloadBytes = 5 * 1024 * 1024;

class SyncBatch {
  const SyncBatch(this.items);

  final List<SyncQueueData> items;

  int get length => items.length;

  bool get isEmpty => items.isEmpty;
}

/// Groups pending queue rows for `POST /v1/sync/events`.
///
/// - Same `reference_id` → one indivisible group (SYNC-PROTOCOL.md §2.5).
/// - `reference_id == null` → each row is its own group.
/// - A group is never split across batches.
/// - If adding a group would exceed [maxEvents] or [maxPayloadBytes], the
///   current batch is closed and the group starts the next one.
/// - A single group larger than the limits is still sent as its own batch
///   (never split). The server may return 413; that is retried as transient.
List<SyncBatch> buildBatches(
  List<SyncQueueData> queue, {
  int maxEvents = kSyncMaxEventsPerBatch,
  int maxPayloadBytes = kSyncMaxPayloadBytes,
}) {
  if (queue.isEmpty) return const [];

  final groups = _partitionGroups(queue);
  final batches = <SyncBatch>[];
  var current = <SyncQueueData>[];

  for (final group in groups) {
    final combined = [...current, ...group];
    final wouldExceedCount = combined.length > maxEvents;
    final wouldExceedBytes =
        _requestBytes(combined) > maxPayloadBytes;

    if (current.isNotEmpty && (wouldExceedCount || wouldExceedBytes)) {
      batches.add(SyncBatch(List.unmodifiable(current)));
      current = [...group];
    } else {
      current = combined;
    }
  }

  if (current.isNotEmpty) {
    batches.add(SyncBatch(List.unmodifiable(current)));
  }

  return batches;
}

List<List<SyncQueueData>> _partitionGroups(List<SyncQueueData> queue) {
  final groups = <List<SyncQueueData>>[];
  final seenReferenceIds = <String>{};

  for (final item in queue) {
    final referenceId = item.referenceId;
    if (referenceId == null) {
      groups.add([item]);
      continue;
    }
    if (seenReferenceIds.contains(referenceId)) continue;
    seenReferenceIds.add(referenceId);
    groups.add(
      queue.where((e) => e.referenceId == referenceId).toList(),
    );
  }

  return groups;
}

int _requestBytes(List<SyncQueueData> items) {
  if (items.isEmpty) return 0;
  final deviceId = items.first.deviceId;
  final body = <String, dynamic>{
    'device_id': deviceId,
    'events': items.map(decodeQueuePayload).toList(),
  };
  return utf8.encode(jsonEncode(body)).length;
}

/// Decodes a queue row's JSON payload for the wire `events[]` array.
Object? decodeQueuePayload(SyncQueueData item) {
  try {
    return jsonDecode(item.payload);
  } on FormatException {
    return item.payload;
  }
}

import 'package:logger/logger.dart';

import '../database/app_database.dart';
import 'sync_event.dart';

/// Permanent-rejection reason codes — API-SPEC.md §6.1.
abstract final class SyncRejectionReason {
  static const categoryHasProducts = 'CATEGORY_HAS_PRODUCTS';
  static const voidWindowClosed = 'VOID_WINDOW_CLOSED';
  static const roleNotPermitted = 'ROLE_NOT_PERMITTED';
  static const eventValidationFailed = 'EVENT_VALIDATION_FAILED';
}

class RejectedEvent {
  const RejectedEvent({
    required this.id,
    this.referenceId,
    required this.reason,
    required this.message,
    this.detail = const {},
  });

  final String id;
  final String? referenceId;
  final String reason;
  final String message;
  final Map<String, dynamic> detail;

  factory RejectedEvent.fromJson(Map<String, dynamic> json) {
    final detailRaw = json['detail'];
    return RejectedEvent(
      id: json['id'] as String,
      referenceId: json['reference_id'] as String?,
      reason: json['reason'] as String? ?? '',
      message: json['message'] as String? ?? '',
      detail: detailRaw is Map<String, dynamic>
          ? detailRaw
          : const <String, dynamic>{},
    );
  }

  bool get isGrouped => referenceId != null && referenceId!.isNotEmpty;
}

class SyncNotice {
  const SyncNotice({
    required this.message,
    this.saleId,
    required this.createdAt,
  });

  final String message;
  final String? saleId;
  final int createdAt;
}

/// In-memory deferred notices for the sync status screen.
/// DATA-MODEL.md / SYNC-PROTOCOL.md §11.2: no new schema for this.
class SyncNoticeStore {
  final List<SyncNotice> _items = [];

  List<SyncNotice> get items => List.unmodifiable(_items);

  void record(SyncNotice notice) => _items.add(notice);
}

/// Device-side permanent rejection (G1 / SYNC-PROTOCOL.md §4.4).
///
/// Never emits a compensating event. Runs only from the background flusher.
class SyncRejectionHandler {
  SyncRejectionHandler({
    required AppDatabase db,
    required SyncNoticeStore notices,
    Logger? logger,
    int Function()? nowMs,
  })  : _db = db,
        _notices = notices,
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs;

  final AppDatabase _db;
  final SyncNoticeStore _notices;
  final Logger _log;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Reconciles one rejected event or group in a single SQLite transaction.
  Future<void> handleRejection(RejectedEvent rejection) async {
    try {
      SyncNotice? notice;
      await _db.transaction(() async {
        final now = _nowMs();
        final queueItems = await _loadQueueItems(rejection);
        final eventTypes = queueItems.map((e) => e.eventType).toSet();
        if (eventTypes.isEmpty) {
          eventTypes.addAll(await _eventTypesFromInventory(rejection));
        }

        if (rejection.isGrouped) {
          await _db.inventoryEventDao
              .markGroupRejected(rejection.referenceId!, now);
        } else {
          await _db.inventoryEventDao.markRejected(rejection.id, now);
        }

        if (_shouldRevertSale(eventTypes)) {
          await _db.saleDao.restoreCompleted(_saleId(rejection));
        }

        if (rejection.isGrouped) {
          await _db.syncQueueDao.deleteGroup(rejection.referenceId!);
        } else {
          await _db.syncQueueDao.deleteById(rejection.id);
        }

        final sale = await _db.saleDao.getById(_saleId(rejection));
        notice = SyncNotice(
          message: _buildRejectionMessage(
            rejection: rejection,
            saleNumber: sale?.saleNumber,
          ),
          saleId: sale?.id,
          createdAt: now,
        );
      });
      if (notice != null) _notices.record(notice!);
    } catch (error, stack) {
      _log.e(
        'Could not apply a sync rejection locally',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<SyncQueueData>> _loadQueueItems(RejectedEvent rejection) async {
    if (rejection.isGrouped) {
      return _db.syncQueueDao.getByReferenceId(rejection.referenceId!);
    }
    final item = await _db.syncQueueDao.getById(rejection.id);
    return item == null ? const [] : [item];
  }

  Future<Set<String>> _eventTypesFromInventory(RejectedEvent rejection) async {
    if (rejection.isGrouped) {
      final rows = await _db.inventoryEventDao
          .getByReferenceId(rejection.referenceId!);
      return rows.map((e) => e.eventType).toSet();
    }
    final row = await _db.inventoryEventDao.getById(rejection.id);
    return row == null ? <String>{} : {row.eventType};
  }

  bool _shouldRevertSale(Set<String> eventTypes) =>
      eventTypes.contains(SyncEventType.saleCreated) ||
      eventTypes.contains(SyncEventType.inventoryVoided);

  String _saleId(RejectedEvent rejection) =>
      rejection.referenceId ?? rejection.id;

  String _buildRejectionMessage({
    required RejectedEvent rejection,
    String? saleNumber,
  }) {
    if (saleNumber != null && saleNumber.isNotEmpty) {
      if (rejection.reason == SyncRejectionReason.voidWindowClosed) {
        return 'Sale $saleNumber could not be cancelled. The shop day had ended.';
      }
      if (rejection.message.isNotEmpty) {
        return 'Sale $saleNumber: ${rejection.message}';
      }
      return 'Sale $saleNumber could not be saved.';
    }
    if (rejection.message.isNotEmpty) return rejection.message;
    return 'A change could not be saved.';
  }
}

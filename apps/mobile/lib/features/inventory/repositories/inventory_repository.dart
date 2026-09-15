import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

class InventoryRepository {
  InventoryRepository({
    required AppDatabase db,
    required AppIdentity identity,
    UuidGenerator? uuids,
    Logger? logger,
    int Function()? nowMs,
  })  : _db = db,
        _identity = identity,
        _uuids = uuids ?? UuidGenerator(),
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs;

  final AppDatabase _db;
  final AppIdentity _identity;
  final UuidGenerator _uuids;
  final Logger _log;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<int> stockOf(String productId) =>
      _db.inventoryEventDao.computeStock(productId);

  Stream<int> watchStock(String productId) {
    return _db.inventoryEventDao.watchByProductId(productId).asyncMap(
          (_) => _db.inventoryEventDao.computeStock(productId),
        );
  }

  Future<List<InventoryEvent>> listForProduct(String productId) {
    return (_db.select(_db.inventoryEvents)
          ..where((e) => e.productId.equals(productId))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Signed [quantityDelta]. Note is required (API-SPEC.md §5).
  Future<void> adjust({
    required String productId,
    required int quantityDelta,
    required String note,
  }) {
    return _appendStandalone(
      productId: productId,
      eventType: SyncEventType.inventoryAdjusted,
      referenceType: 'adjustment',
      quantityDelta: quantityDelta,
      note: note,
      noteRequired: true,
    );
  }

  /// [quantity] is units removed; stored as a negative delta.
  Future<void> damage({
    required String productId,
    required int quantity,
    required String note,
  }) {
    if (quantity <= 0) {
      throw const RepositoryException('Quantity must be greater than zero.');
    }
    return _appendStandalone(
      productId: productId,
      eventType: SyncEventType.inventoryDamaged,
      referenceType: 'damage',
      quantityDelta: -quantity,
      note: note,
      noteRequired: true,
    );
  }

  Future<void> customerReturn({
    required String productId,
    required int quantity,
    String? note,
  }) {
    if (quantity <= 0) {
      throw const RepositoryException('Quantity must be greater than zero.');
    }
    return _appendStandalone(
      productId: productId,
      eventType: SyncEventType.inventoryReturned,
      referenceType: 'return',
      quantityDelta: quantity,
      note: note,
      noteRequired: false,
    );
  }

  Future<void> _appendStandalone({
    required String productId,
    required String eventType,
    required String referenceType,
    required int quantityDelta,
    required String? note,
    required bool noteRequired,
  }) {
    return runRepositoryWrite(
      _log,
      'Could not save stock change',
      'Could not save the stock change. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final trimmedNote = note?.trim();
        if (noteRequired && (trimmedNote == null || trimmedNote.isEmpty)) {
          throw const RepositoryException(
            'Please add a note for this stock change.',
            code: 'EVENT_VALIDATION_FAILED',
          );
        }
        final product = await _db.productDao.getActiveById(productId);
        if (product == null) {
          throw const RepositoryException('That product is no longer available.');
        }
        final id = _uuids.v4();
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.inventoryEventDao.insertEvent(
            InventoryEventsCompanion.insert(
              id: id,
              productId: productId,
              eventType: eventType,
              quantityDelta: quantityDelta,
              referenceType: referenceType,
              note: Value(trimmedNote),
              operatorId: operatorId,
              deviceId: deviceId,
              createdAt: now,
            ),
          );
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: eventType,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            extra: {
              'product_id': productId,
              'quantity_delta': quantityDelta,
              'reference_type': referenceType,
              'note': trimmedNote,
            },
          );
        });
      },
    );
  }
}

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

/// Stock is always computed — never stored on the product row.
class ProductStock {
  const ProductStock({
    required this.product,
    required this.currentStock,
  });

  final Product product;
  final int currentStock;

  /// Zero or below — shown in red, never hidden.
  bool get isOutOfStock => currentStock <= 0;

  /// Below or at threshold but still positive.
  bool get isLowStock =>
      currentStock > 0 && currentStock <= product.lowStockThreshold;

  bool get isNegative => currentStock < 0;

  bool get isHealthy => currentStock > product.lowStockThreshold;
}

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

  Stream<Map<String, int>> watchStockByProduct() {
    return _db.select(_db.inventoryEvents).watch().asyncMap((_) async {
      final products = await _db.productDao.getAllActive();
      final map = <String, int>{};
      for (final product in products) {
        map[product.id] = await _db.inventoryEventDao.computeStock(product.id);
      }
      return map;
    });
  }

  /// Active products with stock from `SUM(quantity_delta)` excluding rejected.
  Future<List<ProductStock>> getStockLevels() async {
    final products = await _db.productDao.getAllActive();
    final levels = <ProductStock>[];
    for (final product in products) {
      final stock = await _db.inventoryEventDao.computeStock(product.id);
      levels.add(ProductStock(product: product, currentStock: stock));
    }
    levels.sort(
      (a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()),
    );
    return levels;
  }

  Stream<List<ProductStock>> watchStockLevels() {
    late final StreamController<List<ProductStock>> controller;
    var busy = false;

    Future<void> emit() async {
      if (busy || controller.isClosed) return;
      busy = true;
      try {
        final levels = await getStockLevels();
        if (!controller.isClosed) controller.add(levels);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        busy = false;
      }
    }

    StreamSubscription<List<Product>>? productsSub;
    StreamSubscription<List<InventoryEvent>>? eventsSub;

    controller = StreamController<List<ProductStock>>(
      onListen: () {
        emit();
        productsSub = _db.productDao.watchAllActive().listen((_) => emit());
        eventsSub =
            _db.select(_db.inventoryEvents).watch().listen((_) => emit());
      },
      onCancel: () async {
        await productsSub?.cancel();
        await eventsSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<ProductStock>> watchLowStock() {
    return watchStockLevels().map(
      (levels) =>
          levels.where((row) => row.isLowStock || row.isOutOfStock).toList(),
    );
  }

  Future<ProductStock?> stockLevelFor(String productId) async {
    final product = await _db.productDao.getActiveById(productId);
    if (product == null) return null;
    final stock = await _db.inventoryEventDao.computeStock(productId);
    return ProductStock(product: product, currentStock: stock);
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

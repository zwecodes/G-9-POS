import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

class ProductDraft {
  const ProductDraft({
    this.categoryId,
    required this.name,
    this.barcode,
    required this.priceMmk,
    this.costPriceMmk,
    this.unit = 'pcs',
    this.lowStockThreshold = 5,
    this.imagePath,
    this.isActive = true,
  });

  final String? categoryId;
  final String name;
  final String? barcode;
  final int priceMmk;
  final int? costPriceMmk;
  final String unit;
  final int lowStockThreshold;
  final String? imagePath;
  final bool isActive;
}

class ProductRepository {
  ProductRepository({
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

  Stream<List<Product>> watchAll() => _db.productDao.watchAllActive();

  Stream<List<Product>> watchSellable() => _db.productDao.watchAllActive().map(
        (rows) => rows.where((p) => p.isActive).toList(),
      );

  Future<List<Product>> getAll() => _db.productDao.getAllActive();

  Future<Product?> getById(String id) => _db.productDao.getActiveById(id);

  Future<Product?> getByBarcode(String barcode) =>
      _db.productDao.getByBarcode(barcode);

  Future<Product> create(ProductDraft draft) {
    return runRepositoryWrite(
      _log,
      'Could not create product',
      'Could not save the product. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        _validate(draft);
        await _assertBarcodeFree(draft.barcode, exceptId: null);
        final id = _uuids.v4();
        final now = _nowMs();
        await _writeProduct(
          id: id,
          createdAt: now,
          eventType: SyncEventType.productCreated,
          draft: draft,
        );
        return (await _db.productDao.getById(id))!;
      },
    );
  }

  Future<void> update(String id, ProductDraft draft) {
    return runRepositoryWrite(
      _log,
      'Could not update product',
      'Could not save the product. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        _validate(draft);
        final existing = await _db.productDao.getActiveById(id);
        if (existing == null) {
          throw const RepositoryException('That product is no longer available.');
        }
        await _assertBarcodeFree(draft.barcode, exceptId: id);
        await _writeProduct(
          id: id,
          createdAt: existing.createdAt,
          eventType: SyncEventType.productUpdated,
          draft: draft,
        );
      },
    );
  }

  Future<void> delete(String id) {
    return runRepositoryWrite(
      _log,
      'Could not delete product',
      'Could not delete the product. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final existing = await _db.productDao.getActiveById(id);
        if (existing == null) {
          throw const RepositoryException('That product is no longer available.');
        }
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.productDao.softDelete(id, now);
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.productDeleted,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
          );
        });
      },
    );
  }

  void _validate(ProductDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw const RepositoryException('Please enter a product name.');
    }
    if (draft.priceMmk < 0) {
      throw const RepositoryException('Price cannot be negative.');
    }
  }

  Future<void> _assertBarcodeFree(String? barcode, {required String? exceptId}) async {
    final trimmed = barcode?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final existing = await _db.productDao.getByBarcode(trimmed);
    if (existing != null && existing.id != exceptId) {
      throw const RepositoryException('A product with this barcode already exists.');
    }
  }

  Future<void> _writeProduct({
    required String id,
    required int createdAt,
    required String eventType,
    required ProductDraft draft,
  }) async {
    final now = _nowMs();
    final deviceId = await _identity.deviceId;
    final operatorId = _identity.operatorId;
    final barcode = _emptyToNull(draft.barcode);
    final categoryId = _emptyToNull(draft.categoryId);
    final imagePath = _emptyToNull(draft.imagePath);
    final unit = draft.unit.trim().isEmpty ? 'pcs' : draft.unit.trim();
    await _db.transaction(() async {
      await _db.productDao.upsert(
        ProductsCompanion(
          id: Value(id),
          categoryId: Value(categoryId),
          name: Value(draft.name.trim()),
          barcode: Value(barcode),
          priceMmk: Value(draft.priceMmk),
          costPriceMmk: Value(draft.costPriceMmk),
          unit: Value(unit),
          lowStockThreshold: Value(draft.lowStockThreshold),
          imagePath: Value(imagePath),
          isActive: Value(draft.isActive),
          createdAt: Value(createdAt),
          updatedAt: Value(now),
          deviceId: Value(deviceId),
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
          'category_id': categoryId,
          'name': draft.name.trim(),
          'barcode': barcode,
          'price_mmk': draft.priceMmk,
          'cost_price_mmk': draft.costPriceMmk,
          'unit': unit,
          'low_stock_threshold': draft.lowStockThreshold,
          'image_path': imagePath,
          'is_active': draft.isActive,
        },
      );
    });
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

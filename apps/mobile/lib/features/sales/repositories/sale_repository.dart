import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

class SaleLineInput {
  const SaleLineInput({
    required this.productId,
    required this.productNameSnapshot,
    required this.priceSnapshotMmk,
    required this.quantity,
  });

  final String productId;
  final String productNameSnapshot;
  final int priceSnapshotMmk;
  final int quantity;

  int get subtotalMmk => priceSnapshotMmk * quantity;
}

class CompletedSale {
  const CompletedSale({
    required this.id,
    required this.saleNumber,
    required this.totalAmountMmk,
  });

  final String id;
  final String saleNumber;
  final int totalAmountMmk;
}

class SaleRepository {
  SaleRepository({
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

  Stream<List<Sale>> watchAll() => _db.saleDao.watchAll();

  Future<List<Sale>> getAll() => _db.saleDao.getAll();

  Future<Sale?> getById(String id) => _db.saleDao.getById(id);

  Future<List<SaleItem>> itemsFor(String saleId) =>
      _db.saleItemDao.getBySaleId(saleId);

  /// Local SQLite first, then one grouped queue write. Never calls the network.
  Future<CompletedSale> completeSale({
    required List<SaleLineInput> lines,
    int discountAmountMmk = 0,
    String? note,
    String paymentMethod = 'cash',
  }) {
    return runRepositoryWrite(
      _log,
      'Could not complete sale',
      'Could not complete the sale. Try again.',
      () async {
        if (lines.isEmpty) {
          throw const RepositoryException('Add at least one product to the cart.');
        }
        for (final line in lines) {
          if (line.quantity <= 0) {
            throw const RepositoryException('Quantity must be greater than zero.');
          }
        }
        if (discountAmountMmk < 0) {
          throw const RepositoryException('Discount cannot be negative.');
        }

        final operatorId = _identity.operatorId;
        final deviceId = await _identity.deviceId;
        final now = _nowMs();
        final saleId = _uuids.v4();
        final saleNumber = await _nextSaleNumber();
        final total = lines.fold<int>(0, (sum, line) => sum + line.subtotalMmk);
        final trimmedNote = _emptyToNull(note);

        await _db.transaction(() async {
          await _db.saleDao.upsert(
            SalesCompanion.insert(
              id: saleId,
              saleNumber: saleNumber,
              operatorId: operatorId,
              deviceId: deviceId,
              paymentMethod: paymentMethod,
              totalAmountMmk: total,
              discountAmountMmk: Value(discountAmountMmk),
              note: Value(trimmedNote),
              status: 'completed',
              createdAt: now,
            ),
          );

          final itemRows = <SaleItemsCompanion>[];
          final itemIds = <String>[];
          final inventoryIds = <String>[];
          for (final line in lines) {
            final itemId = _uuids.v4();
            itemIds.add(itemId);
            itemRows.add(
              SaleItemsCompanion.insert(
                id: itemId,
                saleId: saleId,
                productId: line.productId,
                productNameSnapshot: line.productNameSnapshot,
                priceSnapshotMmk: line.priceSnapshotMmk,
                quantity: line.quantity,
                subtotalMmk: line.subtotalMmk,
                createdAt: now,
              ),
            );
            inventoryIds.add(_uuids.v4());
          }
          await _db.saleItemDao.insertAll(itemRows);

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            await _db.inventoryEventDao.insertEvent(
              InventoryEventsCompanion.insert(
                id: inventoryIds[i],
                productId: line.productId,
                eventType: SyncEventType.inventorySold,
                quantityDelta: -line.quantity,
                referenceId: Value(saleId),
                referenceType: 'sale',
                operatorId: operatorId,
                deviceId: deviceId,
                createdAt: now,
              ),
            );
          }

          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: saleId,
            eventType: SyncEventType.saleCreated,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            referenceId: saleId,
            extra: {
              'sale_number': saleNumber,
              'payment_method': paymentMethod,
              'total_amount_mmk': total,
              'discount_amount_mmk': discountAmountMmk,
              'note': trimmedNote,
              'sale_items': [
                for (var i = 0; i < lines.length; i++)
                  {
                    'id': itemIds[i],
                    'product_id': lines[i].productId,
                    'product_name_snapshot': lines[i].productNameSnapshot,
                    'price_snapshot_mmk': lines[i].priceSnapshotMmk,
                    'quantity': lines[i].quantity,
                    'subtotal_mmk': lines[i].subtotalMmk,
                  },
              ],
            },
          );

          for (var i = 0; i < lines.length; i++) {
            await enqueueSyncEvent(
              _db.syncQueueDao,
              id: inventoryIds[i],
              eventType: SyncEventType.inventorySold,
              deviceId: deviceId,
              operatorId: operatorId,
              createdAt: now,
              referenceId: saleId,
              extra: {
                'product_id': lines[i].productId,
                'quantity_delta': -lines[i].quantity,
                'reference_type': 'sale',
              },
            );
          }
        });

        return CompletedSale(
          id: saleId,
          saleNumber: saleNumber,
          totalAmountMmk: total,
        );
      },
    );
  }

  Future<void> voidSale({
    required String saleId,
    required String reason,
  }) {
    return runRepositoryWrite(
      _log,
      'Could not void sale',
      'Could not cancel the sale. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final trimmed = reason.trim();
        if (trimmed.isEmpty) {
          throw const RepositoryException('Please enter a reason for cancelling.');
        }
        final sale = await _db.saleDao.getById(saleId);
        if (sale == null) {
          throw const RepositoryException('That sale is no longer available.');
        }
        if (sale.status == 'voided') {
          throw const RepositoryException('This sale is already cancelled.');
        }

        final operatorId = _identity.operatorId;
        final deviceId = await _identity.deviceId;
        final now = _nowMs();
        final voidEventId = _uuids.v4();
        final items = await _db.saleItemDao.getBySaleId(saleId);

        await _db.transaction(() async {
          await _db.saleDao.markVoided(
            id: saleId,
            voidedAt: now,
            voidedBy: operatorId,
            voidReason: trimmed,
          );

          final inventoryIds = <String>[
            for (final _ in items) _uuids.v4(),
          ];
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            await _db.inventoryEventDao.insertEvent(
              InventoryEventsCompanion.insert(
                id: inventoryIds[i],
                productId: item.productId,
                eventType: SyncEventType.inventoryVoided,
                quantityDelta: item.quantity,
                referenceId: Value(saleId),
                referenceType: 'sale_void',
                operatorId: operatorId,
                deviceId: deviceId,
                createdAt: now,
              ),
            );
          }

          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: voidEventId,
            eventType: SyncEventType.saleVoided,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            referenceId: saleId,
            extra: {
              'void_reason': trimmed,
              'voided_by': operatorId,
            },
          );
          for (var i = 0; i < items.length; i++) {
            await enqueueSyncEvent(
              _db.syncQueueDao,
              id: inventoryIds[i],
              eventType: SyncEventType.inventoryVoided,
              deviceId: deviceId,
              operatorId: operatorId,
              createdAt: now,
              referenceId: saleId,
              extra: {
                'product_id': items[i].productId,
                'quantity_delta': items[i].quantity,
                'reference_type': 'sale_void',
              },
            );
          }
        });
      },
    );
  }

  Future<String> _nextSaleNumber() async {
    final count = await _db.saleDao.countAll();
    return 'S-${(count + 1).toString().padLeft(5, '0')}';
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

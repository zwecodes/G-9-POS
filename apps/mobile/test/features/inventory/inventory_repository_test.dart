import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/database/app_database.dart';
import 'package:g9pos/core/sync/sync_event.dart';
import 'package:g9pos/core/utils/repository_exception.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('stock is SUM(quantity_delta) excluding rejected rows', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Pad', priceMmk: 2000),
    );
    await repos.inventory.adjust(
      productId: product.id,
      quantityDelta: 10,
      note: 'Opening stock',
    );
    expect(await repos.inventory.stockOf(product.id), 10);

    await repos.db.inventoryEventDao.insertEvent(
      InventoryEventsCompanion.insert(
        id: 'rejected-1',
        productId: product.id,
        eventType: SyncEventType.inventoryAdjusted,
        quantityDelta: 50,
        referenceType: 'adjustment',
        note: const Value('ghost'),
        operatorId: 'owner-1',
        deviceId: 'device-1',
        createdAt: 2,
        rejectedAt: const Value(3),
      ),
    );
    expect(await repos.inventory.stockOf(product.id), 10);
  });

  test('adjust and damage require a note', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Pad', priceMmk: 2000),
    );

    expect(
      () => repos.inventory.adjust(
        productId: product.id,
        quantityDelta: 1,
        note: '  ',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          'EVENT_VALIDATION_FAILED',
        ),
      ),
    );
    expect(
      () => repos.inventory.damage(
        productId: product.id,
        quantity: 1,
        note: '',
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          'EVENT_VALIDATION_FAILED',
        ),
      ),
    );
  });

  test('adjust enqueues a standalone event with a unique id', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Pad', priceMmk: 2000),
    );
    await repos.inventory.adjust(
      productId: product.id,
      quantityDelta: 4,
      note: 'Count correction',
    );

    final pending = await repos.db.syncQueueDao.getPending();
    final row = pending.singleWhere(
      (e) => e.eventType == SyncEventType.inventoryAdjusted,
    );
    expect(row.id, isNot(product.id));
    expect(row.referenceId, isNull);

    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    expect(payload['product_id'], product.id);
    expect(payload['quantity_delta'], 4);
    expect(payload['note'], 'Count correction');
    expect(payload['reference_id'], isNull);
  });
}

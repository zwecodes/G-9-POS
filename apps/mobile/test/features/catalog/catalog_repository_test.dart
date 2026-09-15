import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/sync/sync_event.dart';
import 'package:g9pos/core/utils/repository_exception.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('category create enqueues a standalone CATEGORY_CREATED event', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final category = await repos.categories.create(name: 'Helmets', sortOrder: 1);
    final pending = await repos.db.syncQueueDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.eventType, SyncEventType.categoryCreated);
    expect(pending.single.referenceId, isNull);
    expect(pending.single.id, category.id);

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['id'], category.id);
    expect(payload['event_type'], SyncEventType.categoryCreated);
    expect(payload['reference_id'], isNull);
    expect(payload['name'], 'Helmets');
    expect(payload['sort_order'], 1);
  });

  test('category delete is blocked while active products remain', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final category = await repos.categories.create(name: 'Lights');
    await repos.products.create(
      ProductDraft(name: 'LED', priceMmk: 5000, categoryId: category.id),
    );

    expect(
      () => repos.categories.delete(category.id),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          'CATEGORY_HAS_PRODUCTS',
        ),
      ),
    );
  });

  test('product update replaces the pending LWW queue row', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Horn', priceMmk: 3000, barcode: '111'),
    );
    await repos.products.update(
      product.id,
      const ProductDraft(name: 'Horn XL', priceMmk: 3500, barcode: '111'),
    );

    final pending = await repos.db.syncQueueDao.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, product.id);
    expect(pending.single.eventType, SyncEventType.productUpdated);
    expect(pending.single.referenceId, isNull);

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['name'], 'Horn XL');
    expect(payload['price_mmk'], 3500);
    expect(payload['reference_id'], isNull);
  });

  test('staff cannot create products', () async {
    final repos = openTestRepos(
      identity: testIdentity(operatorId: 'staff-1', operatorRole: 'staff'),
    );
    addTearDown(repos.close);

    expect(
      () => repos.products.create(
        const ProductDraft(name: 'Oil', priceMmk: 1000),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          'ROLE_NOT_PERMITTED',
        ),
      ),
    );
  });

  test('duplicate barcode is rejected locally', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    await repos.products.create(
      const ProductDraft(name: 'A', priceMmk: 1, barcode: 'abc'),
    );
    expect(
      () => repos.products.create(
        const ProductDraft(name: 'B', priceMmk: 1, barcode: 'abc'),
      ),
      throwsA(isA<RepositoryException>()),
    );
  });
}

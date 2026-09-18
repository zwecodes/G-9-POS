import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/database/app_database.dart';
import 'package:g9pos/core/sync/sync_cursor.dart';
import 'package:g9pos/core/sync/sync_flusher.dart';
import 'package:g9pos/core/sync/sync_pull_applier.dart';
import 'package:g9pos/core/sync/sync_pull_payload.dart';
import 'package:g9pos/core/sync/sync_puller.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';
import 'package:g9pos/features/sales/repositories/sale_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('pull applies catalog and inventory without enqueueing', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final payload = parsePullPayload(
      jsonEncode({
        'data': {
          'categories': [
            {
              'id': 'cat-1',
              'name': 'Helmets',
              'sort_order': 1,
              'created_at': 100,
              'updated_at': 100,
              'device_id': 'server',
            },
          ],
          'products': [
            {
              'id': 'prod-1',
              'category_id': 'cat-1',
              'name': 'Full Face',
              'price_mmk': 25000,
              'unit': 'pcs',
              'low_stock_threshold': 5,
              'is_active': true,
              'stock_negative': false,
              'created_at': 100,
              'updated_at': 100,
              'device_id': 'server',
            },
          ],
          'inventory_events': [
            {
              'id': 'inv-1',
              'product_id': 'prod-1',
              'event_type': 'INVENTORY_ADJUSTED',
              'quantity_delta': 10,
              'reference_id': null,
              'reference_type': 'adjustment',
              'note': 'Opening stock',
              'operator_id': 'owner-1',
              'device_id': 'server',
              'created_at': 100,
            },
          ],
        },
        'meta': {'request_id': 'req-1'},
      }),
    );

    await SyncPullApplier(db: repos.db, nowMs: () => 999).apply(payload);

    final product = await repos.db.productDao.getById('prod-1');
    expect(product?.name, 'Full Face');
    expect(await repos.db.inventoryEventDao.computeStock('prod-1'), 10);
    expect(await repos.db.syncQueueDao.getPending(), isEmpty);
  });

  test('pull keeps the newer local product and ignores password hashes', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    await repos.db.productDao.upsert(
      ProductsCompanion(
        id: const Value('prod-local'),
        name: const Value('Horn'),
        priceMmk: const Value(3000),
        createdAt: const Value(5000),
        updatedAt: const Value(5000),
        deviceId: const Value('device-1'),
      ),
    );

    final payload = parsePullPayload(
      jsonEncode({
        'data': {
          'products': [
            {
              'id': 'prod-local',
              'name': 'Older server name',
              'price_mmk': 1,
              'created_at': 1,
              'updated_at': 1,
              'device_id': 'server',
            },
          ],
          'users': [
            {
              'id': 'user-1',
              'name': 'Owner',
              'pin': r'$2b$10$pulledhash',
              'role': 'owner',
              'password_hash': 'must-not-store',
              'created_at': 10,
              'updated_at': 10,
            },
          ],
        },
      }),
    );
    await SyncPullApplier(db: repos.db, nowMs: () => 999).apply(payload);

    final product = await repos.db.productDao.getById('prod-local');
    expect(product?.name, 'Horn');

    final user = await (repos.db.select(repos.db.users)
          ..where((u) => u.id.equals('user-1')))
        .getSingle();
    expect(user.pin, r'$2b$10$pulledhash');
    expect(user.name, 'Owner');
  });

  test('pending local queue row is not overwritten by pull', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final product = await repos.products.create(
      const ProductDraft(name: 'Local', priceMmk: 1000),
    );

    final payload = parsePullPayload(
      jsonEncode({
        'data': {
          'products': [
            {
              'id': product.id,
              'name': 'From other device',
              'price_mmk': 9999,
              'created_at': 9e12,
              'updated_at': 9e12,
              'device_id': 'other',
            },
          ],
        },
      }),
    );
    await SyncPullApplier(db: repos.db, nowMs: () => 999).apply(payload);
    final after = await repos.db.productDao.getById(product.id);
    expect(after?.name, 'Local');
  });

  test('sale_server_received stamps a local sale', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final product = await repos.products.create(
      const ProductDraft(name: 'Grip', priceMmk: 2000),
    );
    await repos.inventory.adjust(
      productId: product.id,
      quantityDelta: 2,
      note: 'open',
    );
    final sale = await repos.sales.completeSale(
      paymentMethod: 'cash',
      lines: [
        SaleLineInput(
          productId: product.id,
          productNameSnapshot: 'Grip',
          priceSnapshotMmk: 2000,
          quantity: 1,
        ),
      ],
    );

    final payload = parsePullPayload(
      jsonEncode({
        'data': {
          'sale_server_received': [
            {'id': sale.id, 'server_received_at': 555},
          ],
        },
      }),
    );
    await SyncPullApplier(db: repos.db, nowMs: () => 999).apply(payload);
    final row = await repos.db.saleDao.getById(sale.id);
    expect(row?.serverReceivedAt, 555);
  });

  test('puller pages until under the 200-row limit', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final cursor = SyncCursor(memory: {});
    var calls = 0;
    final page1 = List.generate(
      kSyncPullPageSize,
      (i) => {
        'id': 'p-$i',
        'name': 'P$i',
        'price_mmk': 100,
        'created_at': i + 1,
        'updated_at': i + 1,
        'device_id': 'server',
      },
    );

    final puller = SyncPuller(
      applier: SyncPullApplier(db: repos.db, nowMs: () => 1000),
      cursor: cursor,
      accessToken: () async => 'token',
      deviceId: () async => 'device-b',
      nowMs: () => 1000,
      getter: ({required uri, required accessToken}) async {
        calls += 1;
        if (calls == 1) {
          return jsonEncode({
            'data': {'products': page1},
          });
        }
        return jsonEncode({
          'data': {
            'products': [
              {
                'id': 'p-last',
                'name': 'Last',
                'price_mmk': 100,
                'created_at': 500,
                'updated_at': 500,
                'device_id': 'server',
              },
            ],
          },
        });
      },
    );

    await puller.pull();
    expect(calls, 2);
    expect(await cursor.getLastSyncAtMs(), 1000);
    expect(await repos.db.productDao.getById('p-0'), isNot(null));
    expect(await repos.db.productDao.getById('p-last'), isNot(null));
  });

  test('puller skips expired tokens without calling the server', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    var calls = 0;
    final puller = SyncPuller(
      applier: SyncPullApplier(db: repos.db, nowMs: () => 1),
      cursor: SyncCursor(memory: {}),
      accessToken: () async => 'expired',
      accessTokenValid: () async => false,
      deviceId: () async => 'device-b',
      getter: ({required uri, required accessToken}) async {
        calls += 1;
        throw const SyncHttpException(401, 'Authentication required');
      },
    );

    await puller.pull();
    expect(calls, 0);
  });

  test('puller does not throw on HTTP 401', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final puller = SyncPuller(
      applier: SyncPullApplier(db: repos.db, nowMs: () => 1),
      cursor: SyncCursor(memory: {}),
      accessToken: () async => 'stale',
      deviceId: () async => 'device-b',
      getter: ({required uri, required accessToken}) async {
        throw const SyncHttpException(401, 'Authentication required');
      },
    );

    await puller.pull();
  });

  test('puller does not throw when the server is unreachable', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final puller = SyncPuller(
      applier: SyncPullApplier(db: repos.db, nowMs: () => 1),
      cursor: SyncCursor(memory: {}),
      accessToken: () async => 'token',
      deviceId: () async => 'device-b',
      getter: ({required uri, required accessToken}) async {
        throw Exception('connection refused');
      },
    );

    await puller.pull();
  });
}

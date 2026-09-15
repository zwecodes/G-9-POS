import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/sync/sync_batch.dart';
import 'package:g9pos/core/sync/sync_event.dart';
import 'package:g9pos/core/utils/repository_exception.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';
import 'package:g9pos/features/sales/repositories/sale_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('completeSale writes SQLite then one grouped queue payload', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final helmet = await repos.products.create(
      const ProductDraft(name: 'Helmet', priceMmk: 13000),
    );
    final glove = await repos.products.create(
      const ProductDraft(name: 'Glove', priceMmk: 4000),
    );

    final completed = await repos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: helmet.id,
          productNameSnapshot: 'Helmet',
          priceSnapshotMmk: 13000,
          quantity: 2,
        ),
        SaleLineInput(
          productId: glove.id,
          productNameSnapshot: 'Glove',
          priceSnapshotMmk: 4000,
          quantity: 1,
        ),
      ],
    );

    expect(completed.saleNumber, 'S-00001');
    final sale = await repos.sales.getById(completed.id);
    expect(sale!.status, 'completed');
    expect(sale.totalAmountMmk, 30000);

    final items = await repos.sales.itemsFor(completed.id);
    expect(items, hasLength(2));

    expect(await repos.inventory.stockOf(helmet.id), -2);
    expect(await repos.inventory.stockOf(glove.id), -1);

    final pending = await repos.db.syncQueueDao.getPending();
    final saleGroup =
        pending.where((e) => e.referenceId == completed.id).toList();
    expect(saleGroup, hasLength(3));
    expect(saleGroup.first.eventType, SyncEventType.saleCreated);
    expect(saleGroup.first.id, completed.id);

    final salePayload =
        jsonDecode(saleGroup.first.payload) as Map<String, dynamic>;
    expect(salePayload['id'], completed.id);
    expect(salePayload['reference_id'], completed.id);
    expect(salePayload['sale_items'], hasLength(2));
    expect(salePayload['total_amount_mmk'], 30000);

    final batches = buildBatches(saleGroup);
    expect(batches, hasLength(1));
    expect(batches.single.length, 3);
  });

  test('a sale is never blocked by negative stock', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Oil', priceMmk: 1000),
    );
    await repos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: product.id,
          productNameSnapshot: 'Oil',
          priceSnapshotMmk: 1000,
          quantity: 5,
        ),
      ],
    );
    expect(await repos.inventory.stockOf(product.id), -5);
  });

  test('owner void restores stock in a second group keyed by the sale',
      () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Oil', priceMmk: 1000),
    );
    final completed = await repos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: product.id,
          productNameSnapshot: 'Oil',
          priceSnapshotMmk: 1000,
          quantity: 3,
        ),
      ],
    );
    await repos.sales.voidSale(saleId: completed.id, reason: 'Wrong item');

    final sale = await repos.sales.getById(completed.id);
    expect(sale!.status, 'voided');
    expect(await repos.inventory.stockOf(product.id), 0);

    final pending = await repos.db.syncQueueDao.getPending();
    final voidRows = pending
        .where(
          (e) =>
              e.eventType == SyncEventType.saleVoided ||
              e.eventType == SyncEventType.inventoryVoided,
        )
        .toList();
    expect(voidRows, hasLength(2));
    expect(voidRows.every((e) => e.referenceId == completed.id), isTrue);
    expect(
      voidRows.where((e) => e.eventType == SyncEventType.saleVoided).single.id,
      isNot(completed.id),
    );
  });

  test('staff cannot void a sale', () async {
    final ownerRepos = openTestRepos();
    addTearDown(ownerRepos.close);
    final product = await ownerRepos.products.create(
      const ProductDraft(name: 'Oil', priceMmk: 1000),
    );
    final completed = await ownerRepos.sales.completeSale(
      lines: [
        SaleLineInput(
          productId: product.id,
          productNameSnapshot: 'Oil',
          priceSnapshotMmk: 1000,
          quantity: 1,
        ),
      ],
    );

    final staffSales = SaleRepository(
      db: ownerRepos.db,
      identity: testIdentity(operatorId: 'staff-1', operatorRole: 'staff'),
    );
    expect(
      () => staffSales.voidSale(saleId: completed.id, reason: 'mistake'),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.code,
          'code',
          'ROLE_NOT_PERMITTED',
        ),
      ),
    );
  });

  test('locked session cannot complete a sale', () async {
    final repos = openTestRepos(
      identity: testIdentity(operatorId: ''),
    );
    addTearDown(repos.close);

    expect(
      () => repos.sales.completeSale(
        lines: [
          const SaleLineInput(
            productId: 'p1',
            productNameSnapshot: 'X',
            priceSnapshotMmk: 1,
            quantity: 1,
          ),
        ],
      ),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          'Please unlock with your PIN first.',
        ),
      ),
    );
  });
}

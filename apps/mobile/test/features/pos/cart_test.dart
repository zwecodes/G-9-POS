import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/utils/repository_exception.dart';
import 'package:g9pos/features/pos/providers/cart_provider.dart';
import 'package:g9pos/features/products/repositories/product_repository.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('cart merges quantity and snapshots price at add time', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final product = await repos.products.create(
      const ProductDraft(name: 'Helmet', priceMmk: 13000, barcode: 'H1'),
    );
    final cart = CartNotifier(repos.products);
    await cart.addByBarcode('H1');
    cart.addProduct(product);
    expect(cart.state.lines, hasLength(1));
    expect(cart.state.lines.single.quantity, 2);
    expect(cart.state.totalAmountMmk, 26000);

    cart.decrement(product.id);
    expect(cart.state.lines.single.quantity, 1);
    cart.decrement(product.id);
    expect(cart.state.isEmpty, isTrue);
  });

  test('unknown barcode is a plain-language error', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);
    final cart = CartNotifier(repos.products);
    expect(
      () => cart.addByBarcode('missing'),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          'No product matches that barcode.',
        ),
      ),
    );
  });
}

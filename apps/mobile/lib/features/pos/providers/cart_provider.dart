import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/repository_exception.dart';
import '../../products/providers/product_providers.dart';
import '../../products/repositories/product_repository.dart';
import '../../sales/repositories/sale_repository.dart';

class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.priceMmk,
    required this.quantity,
  });

  final String productId;
  final String name;
  final int priceMmk;
  final int quantity;

  int get subtotalMmk => priceMmk * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
        productId: productId,
        name: name,
        priceMmk: priceMmk,
        quantity: quantity ?? this.quantity,
      );

  SaleLineInput toSaleLine() => SaleLineInput(
        productId: productId,
        productNameSnapshot: name,
        priceSnapshotMmk: priceMmk,
        quantity: quantity,
      );
}

class CartState {
  const CartState({
    this.lines = const [],
    this.discountAmountMmk = 0,
    this.note,
  });

  final List<CartLine> lines;
  final int discountAmountMmk;
  final String? note;

  int get totalAmountMmk =>
      lines.fold<int>(0, (sum, line) => sum + line.subtotalMmk);

  int get itemCount =>
      lines.fold<int>(0, (sum, line) => sum + line.quantity);

  bool get isEmpty => lines.isEmpty;

  List<SaleLineInput> toSaleLines() =>
      lines.map((line) => line.toSaleLine()).toList();

  CartState copyWith({
    List<CartLine>? lines,
    int? discountAmountMmk,
    String? note,
    bool clearNote = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      discountAmountMmk: discountAmountMmk ?? this.discountAmountMmk,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._products) : super(const CartState());

  final ProductRepository _products;

  void addProduct(Product product, {int quantity = 1}) {
    if (!product.isActive) {
      throw const RepositoryException('This product is not for sale.');
    }
    if (quantity <= 0) {
      throw const RepositoryException('Quantity must be greater than zero.');
    }
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.productId == product.id);
    if (index >= 0) {
      final current = lines[index];
      lines[index] = current.copyWith(quantity: current.quantity + quantity);
    } else {
      lines.add(
        CartLine(
          productId: product.id,
          name: product.name,
          priceMmk: product.priceMmk,
          quantity: quantity,
        ),
      );
    }
    state = state.copyWith(lines: lines);
  }

  Future<void> addByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw const RepositoryException('Enter a barcode.');
    }
    final product = await _products.getByBarcode(trimmed);
    if (product == null) {
      throw const RepositoryException('No product matches that barcode.');
    }
    addProduct(product);
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    final lines = [
      for (final line in state.lines)
        if (line.productId == productId) line.copyWith(quantity: quantity) else line,
    ];
    state = state.copyWith(lines: lines);
  }

  void increment(String productId) {
    final lines = [
      for (final line in state.lines)
        if (line.productId == productId)
          line.copyWith(quantity: line.quantity + 1)
        else
          line,
    ];
    state = state.copyWith(lines: lines);
  }

  void decrement(String productId) {
    final current = state.lines.where((l) => l.productId == productId);
    if (current.isEmpty) return;
    setQuantity(productId, current.first.quantity - 1);
  }

  void remove(String productId) {
    state = state.copyWith(
      lines: state.lines.where((line) => line.productId != productId).toList(),
    );
  }

  void setDiscount(int amountMmk) {
    if (amountMmk < 0) {
      throw const RepositoryException('Discount cannot be negative.');
    }
    state = state.copyWith(discountAmountMmk: amountMmk);
  }

  void setNote(String? note) {
    final trimmed = note?.trim();
    state = state.copyWith(
      note: trimmed,
      clearNote: trimmed == null || trimmed.isEmpty,
    );
  }

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref.watch(productRepositoryProvider));
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hardware/hardware_provider.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/providers/app_providers.dart';
import 'cart_provider.dart';

/// Listens to [ScannerInterface.onBarcodeScanned] and adds to the cart.
/// Never throws into the UI — failures become [barcodeLookupErrorProvider].
final barcodeLookupErrorProvider = StateProvider<String?>((ref) => null);

final posBarcodeListenerProvider = Provider<void>((ref) {
  final scanner = ref.watch(scannerProvider);
  final log = ref.watch(appLoggerProvider);
  StreamSubscription<String>? sub;

  sub = scanner.onBarcodeScanned.listen((code) async {
    ref.read(barcodeLookupErrorProvider.notifier).state = null;
    try {
      await ref.read(cartProvider.notifier).addByBarcode(code);
    } on RepositoryException catch (error) {
      ref.read(barcodeLookupErrorProvider.notifier).state = error.message;
    } catch (error, stack) {
      log.e('Barcode lookup failed', error: error, stackTrace: stack);
      ref.read(barcodeLookupErrorProvider.notifier).state =
          'Could not add that product. Try again.';
    }
  });

  ref.onDispose(() {
    sub?.cancel();
  });
});

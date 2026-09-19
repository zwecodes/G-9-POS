// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'G9POS';

  @override
  String get navPos => 'POS';

  @override
  String get navProducts => 'Products';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMyanmar => 'မြန်မာ';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInToDevice => 'Sign in to this device';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get unlockWithPin => 'Unlock with PIN';

  @override
  String get unlockThisDevice => 'Unlock this device';

  @override
  String get whoIsSelling => 'Who is selling?';

  @override
  String get continueLabel => 'Continue';

  @override
  String get unlock => 'Unlock';

  @override
  String get pin => 'PIN';

  @override
  String get couldNotLoadStaff => 'Could not load staff. Try again.';

  @override
  String get offlineBanner => 'Offline — sales are saving locally';

  @override
  String get syncStatus => 'Sync status';

  @override
  String get syncNow => 'Sync now';

  @override
  String pendingItems(int count) {
    return 'Pending items: $count';
  }

  @override
  String get notSyncedYet => 'Not synced yet';

  @override
  String lastSynced(String when) {
    return 'Last synced $when';
  }

  @override
  String get notices => 'Notices';

  @override
  String get noSyncProblems => 'No sync problems.';

  @override
  String get syncStaleDay =>
      'Sync is more than a day old. Connect to the internet when you can.';

  @override
  String syncStaleHours(int hours) {
    return 'Last sync was about ${hours}h ago. Still safe to sell.';
  }

  @override
  String get syncStaleFewHours =>
      'Sync is a few hours old. Still safe to sell.';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get inventory => 'Inventory';

  @override
  String get addProduct => 'Add product';

  @override
  String get noProductsYet => 'No products yet — add your first product';

  @override
  String get couldNotLoadProducts => 'Could not load products. Try again.';

  @override
  String get reports => 'Reports';

  @override
  String get reportsOwnerOnly => 'Reports are only available to the owner.';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get custom => 'Custom';

  @override
  String get revenue => 'REVENUE';

  @override
  String get profit => 'Profit';

  @override
  String get incompleteProfit => 'Incomplete — add cost prices to see profit';

  @override
  String get sales => 'Sales';

  @override
  String get itemsSold => 'Items sold';

  @override
  String get topProducts => 'Top Products';

  @override
  String get noSalesInPeriod => 'No sales in this period.';

  @override
  String get expenses => 'Expenses';

  @override
  String get noExpensesInPeriod => 'No expenses in this period.';

  @override
  String get total => 'Total';

  @override
  String get couldNotLoadReport => 'Could not load the report. Try again.';

  @override
  String get settings => 'Settings';

  @override
  String get salesHistory => 'Sales history';

  @override
  String get thisDevice => 'This device';

  @override
  String get deviceSetupChecklist => 'Device setup checklist';

  @override
  String get hardware => 'Hardware';

  @override
  String get changePin => 'Change PIN';

  @override
  String get lockScreen => 'Lock screen';

  @override
  String get signOut => 'Sign out';

  @override
  String get signedIn => 'Signed in';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'You will need the owner password to use this device again.';

  @override
  String get stay => 'Stay';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get keep => 'Keep';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get checkout => 'Checkout';

  @override
  String get saleComplete => 'Sale complete';

  @override
  String get newSale => 'New sale';

  @override
  String get cartEmpty => 'Scan a product or search above to start a sale';

  @override
  String get searchProducts => 'Search products';

  @override
  String get typeBarcode => 'Type barcode';

  @override
  String get addToCart => 'Add';

  @override
  String get payCash => 'Take payment';

  @override
  String get couldNotCompleteSale => 'Could not finish the sale. Try again.';

  @override
  String get ownerOnly => 'Only the owner can do that.';

  @override
  String get inventoryOwnerOnly => 'Inventory is only available to the owner.';

  @override
  String get couldNotLoadStock => 'Could not load stock. Try again.';

  @override
  String allStock(int count) {
    return 'All Stock ($count)';
  }

  @override
  String lowStock(int count) {
    return 'Low Stock ($count)';
  }

  @override
  String outOfStock(int count) {
    return 'Out of Stock ($count)';
  }

  @override
  String get noProductsStock => 'No products yet.';

  @override
  String get noLowStock => 'No products are low on stock.';

  @override
  String get noOutOfStock => 'No products are out of stock.';

  @override
  String get adjustStock => 'Adjust stock';

  @override
  String get stockOwnerOnly => 'Only the owner can change stock.';

  @override
  String get addStock => '+ Add stock';

  @override
  String get removeStock => '- Remove stock';

  @override
  String get whyStockChanging => 'Why is stock changing?';

  @override
  String get saveStockChange => 'Save stock change';

  @override
  String currentStock(int stock) {
    return 'Current stock: $stock';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get saveExpense => 'Save expense';

  @override
  String dateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String get noExpensesYet => 'No expenses recorded today';

  @override
  String get couldNotLoadExpenses => 'Could not load expenses. Try again.';

  @override
  String get noSalesToday => 'No sales today yet';

  @override
  String get couldNotLoadSales => 'Could not load sales. Try again.';

  @override
  String get cancelled => 'CANCELLED';

  @override
  String get cancelThisSale => 'Cancel This Sale';

  @override
  String get cancelSaleTitle => 'Cancel this sale?';

  @override
  String get cancelSaleBody =>
      'Stock will go back. This only works for sales from today.';

  @override
  String get saleUnavailable => 'That sale is no longer available.';

  @override
  String get reprintReceipt => 'Reprint receipt';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesOwnerOnly => 'Only the owner can manage categories.';

  @override
  String get noCategoriesYet => 'No categories yet — add the first one';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get nameRequired => 'Name *';

  @override
  String get deleteCategoryTitle => 'Delete this category?';

  @override
  String deleteCategoryBody(String name) {
    return '\"$name\" will be removed. Products in it must be moved first.';
  }

  @override
  String get couldNotLoadCategories => 'Could not load categories. Try again.';

  @override
  String get couldNotSaveCategory => 'Could not save the category. Try again.';

  @override
  String get couldNotDeleteCategory =>
      'Could not delete the category. Try again.';

  @override
  String get deviceSettingsOwnerOnly =>
      'Only the owner can change device settings.';

  @override
  String deviceId(String id) {
    return 'Device ID: $id';
  }

  @override
  String get deviceName => 'Device name *';

  @override
  String get saveName => 'Save name';

  @override
  String get activePos => 'Active POS';

  @override
  String get activePosHelp =>
      'Mark this tablet or phone as the shop’s active POS. Works offline — it syncs when the internet returns.';

  @override
  String get makeActivePos => 'Make this the active POS';

  @override
  String get deviceNameSaved => 'Device name saved.';

  @override
  String get activePosQueued =>
      'This device will be the active POS after the next successful sync.';

  @override
  String get hardwareTitle => 'Hardware';

  @override
  String get hardwareHelp =>
      'Scanner and printer are not connected yet. Sales still work — type barcodes manually and reprint receipts from history after you pair hardware.';

  @override
  String get barcodeScanner => 'Barcode scanner';

  @override
  String get receiptPrinter => 'Receipt printer';

  @override
  String get hardwareTestsLater =>
      'Test buttons will appear here after Bluetooth pairing is added.';

  @override
  String get changePinTitle => 'Change PIN';

  @override
  String get changePinHelp =>
      'Your PIN unlocks this device. It stays on the device and is never sent to the server.';

  @override
  String get currentPin => 'Current PIN *';

  @override
  String get newPin => 'New PIN *';

  @override
  String get confirmNewPin => 'Confirm new PIN *';

  @override
  String get pinHint => '4–8 digits';

  @override
  String get savePin => 'Save PIN';

  @override
  String get pinSaved => 'PIN saved on this device.';

  @override
  String get pinMismatch => 'New PIN and confirmation do not match.';

  @override
  String get pinInvalid => 'New PIN must be 4 to 8 digits.';

  @override
  String get pinChangeFailed =>
      'Could not change PIN. Check your current PIN and try again.';

  @override
  String get setupTitle => 'Set up this device';

  @override
  String get setupIntro =>
      'Complete these steps before the shop opens. You can skip optional items, but do not skip them on both devices.';

  @override
  String get setupDeviceName => '1. Device name';

  @override
  String get setupDeviceNameHint => 'Name (e.g. Counter tablet)';

  @override
  String get setupHardware => '2. Hardware checklist';

  @override
  String get setupScannerTitle => 'Barcode scanner paired to this device';

  @override
  String get setupScannerSubtitle =>
      'Pair in Android Bluetooth settings, then confirm here.';

  @override
  String get setupPrinterTitle => 'Receipt printer paired to this device';

  @override
  String get setupPrinterSubtitle =>
      'Optional at launch — skip if you have no printer yet.';

  @override
  String get setupOtherTitle => 'Other device (tablet or phone) also set up';

  @override
  String get setupOtherSubtitle =>
      'Both devices must be paired and signed in before opening day.';

  @override
  String get openHardwareStatus => 'Open hardware status';

  @override
  String get setupSync => '3. Sync catalog';

  @override
  String get setupSyncEmpty =>
      'No products on this device yet. Sync now after the catalog was imported on the dashboard.';

  @override
  String setupSyncReady(int count, int pending) {
    return '$count products ready. Pending sync: $pending.';
  }

  @override
  String get setupActivePos => '4. Active POS';

  @override
  String get setupActivePosHelp =>
      'Mark this device as the shop’s active POS, or skip if this is the standby phone.';

  @override
  String get finishSetup => 'Finish setup';

  @override
  String get finishSetupHint =>
      'Mark or skip every checklist item before finishing.';

  @override
  String get needed => 'Needed';

  @override
  String get skipped => 'Skipped';

  @override
  String get syncFinished => 'Sync finished.';

  @override
  String get couldNotSync =>
      'Could not sync. Check the connection and try again — you can still finish setup.';

  @override
  String get nameSavedLocal =>
      'Name saved on this device. It will update on the server when online.';

  @override
  String get enterDeviceName => 'Please enter a device name.';

  @override
  String get productForm => 'Product';

  @override
  String get newProduct => 'New product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get priceMmk => 'Price (MMK) *';

  @override
  String get costPriceMmk => 'Cost price (MMK)';

  @override
  String get costPriceHint => 'Add cost price to see profit in reports';

  @override
  String get barcode => 'Barcode';

  @override
  String get category => 'Category';

  @override
  String get newCategoryName => 'Or type a new category name';

  @override
  String get unit => 'Unit';

  @override
  String get lowStockThreshold => 'Low-stock alert at';

  @override
  String get saveProduct => 'Save product';

  @override
  String get activeProduct => 'Active (sellable)';

  @override
  String get couldNotSaveProduct => 'Could not save the product. Try again.';

  @override
  String get printerNotConnected =>
      'Printer not connected — sale is saved. Reprint from history later.';

  @override
  String get printingReceipt => 'Sending to printer…';

  @override
  String get ago1d => '1d ago';

  @override
  String agoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String get cart => 'Cart';

  @override
  String get completeSale => 'COMPLETE SALE';

  @override
  String get paymentCash => 'Payment: CASH';

  @override
  String get quantity => 'Quantity';

  @override
  String get set => 'Set';

  @override
  String get noProductsFound => 'No products found — try a different name';

  @override
  String stockLabel(int stock) {
    return 'Stock $stock';
  }

  @override
  String get none => 'None';

  @override
  String get deleteProduct => 'Delete product';

  @override
  String get deleteProductTitle => 'Delete this product?';

  @override
  String get deleteProductBody =>
      'It will be hidden from selling. Past sales stay in history.';

  @override
  String get keepIt => 'Keep it';

  @override
  String get quantityRequired => 'Quantity *';

  @override
  String get noteRequired => 'Note *';

  @override
  String get categoryRequired => 'Category *';

  @override
  String get amountRequired => 'Amount (MMK) *';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get reason => 'Reason';

  @override
  String get enterBarcode => 'Enter a barcode.';

  @override
  String get noStaffPinsYet =>
      'No staff PINs on this device yet. Sign in online once to download them.';
}

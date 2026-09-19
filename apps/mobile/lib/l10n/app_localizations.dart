import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('my'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'G9POS'**
  String get appTitle;

  /// No description provided for @navPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get navPos;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageMyanmar.
  ///
  /// In en, this message translates to:
  /// **'မြန်မာ'**
  String get languageMyanmar;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInToDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign in to this device'**
  String get signInToDevice;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @unlockWithPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock with PIN'**
  String get unlockWithPin;

  /// No description provided for @unlockThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Unlock this device'**
  String get unlockThisDevice;

  /// No description provided for @whoIsSelling.
  ///
  /// In en, this message translates to:
  /// **'Who is selling?'**
  String get whoIsSelling;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get pin;

  /// No description provided for @couldNotLoadStaff.
  ///
  /// In en, this message translates to:
  /// **'Could not load staff. Try again.'**
  String get couldNotLoadStaff;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline — sales are saving locally'**
  String get offlineBanner;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncStatus;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @pendingItems.
  ///
  /// In en, this message translates to:
  /// **'Pending items: {count}'**
  String pendingItems(int count);

  /// No description provided for @notSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get notSyncedYet;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}'**
  String lastSynced(String when);

  /// No description provided for @notices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get notices;

  /// No description provided for @noSyncProblems.
  ///
  /// In en, this message translates to:
  /// **'No sync problems.'**
  String get noSyncProblems;

  /// No description provided for @syncStaleDay.
  ///
  /// In en, this message translates to:
  /// **'Sync is more than a day old. Connect to the internet when you can.'**
  String get syncStaleDay;

  /// No description provided for @syncStaleHours.
  ///
  /// In en, this message translates to:
  /// **'Last sync was about {hours}h ago. Still safe to sell.'**
  String syncStaleHours(int hours);

  /// No description provided for @syncStaleFewHours.
  ///
  /// In en, this message translates to:
  /// **'Sync is a few hours old. Still safe to sell.'**
  String get syncStaleFewHours;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet — add your first product'**
  String get noProductsYet;

  /// No description provided for @couldNotLoadProducts.
  ///
  /// In en, this message translates to:
  /// **'Could not load products. Try again.'**
  String get couldNotLoadProducts;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @reportsOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Reports are only available to the owner.'**
  String get reportsOwnerOnly;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'REVENUE'**
  String get revenue;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @incompleteProfit.
  ///
  /// In en, this message translates to:
  /// **'Incomplete — add cost prices to see profit'**
  String get incompleteProfit;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @itemsSold.
  ///
  /// In en, this message translates to:
  /// **'Items sold'**
  String get itemsSold;

  /// No description provided for @topProducts.
  ///
  /// In en, this message translates to:
  /// **'Top Products'**
  String get topProducts;

  /// No description provided for @noSalesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period.'**
  String get noSalesInPeriod;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @noExpensesInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this period.'**
  String get noExpensesInPeriod;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @couldNotLoadReport.
  ///
  /// In en, this message translates to:
  /// **'Could not load the report. Try again.'**
  String get couldNotLoadReport;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales history'**
  String get salesHistory;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @deviceSetupChecklist.
  ///
  /// In en, this message translates to:
  /// **'Device setup checklist'**
  String get deviceSetupChecklist;

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @lockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get lockScreen;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will need the owner password to use this device again.'**
  String get signOutConfirmBody;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @saleComplete.
  ///
  /// In en, this message translates to:
  /// **'Sale complete'**
  String get saleComplete;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get newSale;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Scan a product or search above to start a sale'**
  String get cartEmpty;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// No description provided for @typeBarcode.
  ///
  /// In en, this message translates to:
  /// **'Type barcode'**
  String get typeBarcode;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addToCart;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Take payment'**
  String get payCash;

  /// No description provided for @couldNotCompleteSale.
  ///
  /// In en, this message translates to:
  /// **'Could not finish the sale. Try again.'**
  String get couldNotCompleteSale;

  /// No description provided for @ownerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can do that.'**
  String get ownerOnly;

  /// No description provided for @inventoryOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Inventory is only available to the owner.'**
  String get inventoryOwnerOnly;

  /// No description provided for @couldNotLoadStock.
  ///
  /// In en, this message translates to:
  /// **'Could not load stock. Try again.'**
  String get couldNotLoadStock;

  /// No description provided for @allStock.
  ///
  /// In en, this message translates to:
  /// **'All Stock ({count})'**
  String allStock(int count);

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock ({count})'**
  String lowStock(int count);

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock ({count})'**
  String outOfStock(int count);

  /// No description provided for @noProductsStock.
  ///
  /// In en, this message translates to:
  /// **'No products yet.'**
  String get noProductsStock;

  /// No description provided for @noLowStock.
  ///
  /// In en, this message translates to:
  /// **'No products are low on stock.'**
  String get noLowStock;

  /// No description provided for @noOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'No products are out of stock.'**
  String get noOutOfStock;

  /// No description provided for @adjustStock.
  ///
  /// In en, this message translates to:
  /// **'Adjust stock'**
  String get adjustStock;

  /// No description provided for @stockOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can change stock.'**
  String get stockOwnerOnly;

  /// No description provided for @addStock.
  ///
  /// In en, this message translates to:
  /// **'+ Add stock'**
  String get addStock;

  /// No description provided for @removeStock.
  ///
  /// In en, this message translates to:
  /// **'- Remove stock'**
  String get removeStock;

  /// No description provided for @whyStockChanging.
  ///
  /// In en, this message translates to:
  /// **'Why is stock changing?'**
  String get whyStockChanging;

  /// No description provided for @saveStockChange.
  ///
  /// In en, this message translates to:
  /// **'Save stock change'**
  String get saveStockChange;

  /// No description provided for @currentStock.
  ///
  /// In en, this message translates to:
  /// **'Current stock: {stock}'**
  String currentStock(int stock);

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @saveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get saveExpense;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateLabel(String date);

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded today'**
  String get noExpensesYet;

  /// No description provided for @couldNotLoadExpenses.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses. Try again.'**
  String get couldNotLoadExpenses;

  /// No description provided for @noSalesToday.
  ///
  /// In en, this message translates to:
  /// **'No sales today yet'**
  String get noSalesToday;

  /// No description provided for @couldNotLoadSales.
  ///
  /// In en, this message translates to:
  /// **'Could not load sales. Try again.'**
  String get couldNotLoadSales;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get cancelled;

  /// No description provided for @cancelThisSale.
  ///
  /// In en, this message translates to:
  /// **'Cancel This Sale'**
  String get cancelThisSale;

  /// No description provided for @cancelSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this sale?'**
  String get cancelSaleTitle;

  /// No description provided for @cancelSaleBody.
  ///
  /// In en, this message translates to:
  /// **'Stock will go back. This only works for sales from today.'**
  String get cancelSaleBody;

  /// No description provided for @saleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That sale is no longer available.'**
  String get saleUnavailable;

  /// No description provided for @reprintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reprint receipt'**
  String get reprintReceipt;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can manage categories.'**
  String get categoriesOwnerOnly;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet — add the first one'**
  String get noCategoriesYet;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequired;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed. Products in it must be moved first.'**
  String deleteCategoryBody(String name);

  /// No description provided for @couldNotLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories. Try again.'**
  String get couldNotLoadCategories;

  /// No description provided for @couldNotSaveCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not save the category. Try again.'**
  String get couldNotSaveCategory;

  /// No description provided for @couldNotDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the category. Try again.'**
  String get couldNotDeleteCategory;

  /// No description provided for @deviceSettingsOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can change device settings.'**
  String get deviceSettingsOwnerOnly;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID: {id}'**
  String deviceId(String id);

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name *'**
  String get deviceName;

  /// No description provided for @saveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get saveName;

  /// No description provided for @activePos.
  ///
  /// In en, this message translates to:
  /// **'Active POS'**
  String get activePos;

  /// No description provided for @activePosHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark this tablet or phone as the shop’s active POS. Works offline — it syncs when the internet returns.'**
  String get activePosHelp;

  /// No description provided for @makeActivePos.
  ///
  /// In en, this message translates to:
  /// **'Make this the active POS'**
  String get makeActivePos;

  /// No description provided for @deviceNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Device name saved.'**
  String get deviceNameSaved;

  /// No description provided for @activePosQueued.
  ///
  /// In en, this message translates to:
  /// **'This device will be the active POS after the next successful sync.'**
  String get activePosQueued;

  /// No description provided for @hardwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardwareTitle;

  /// No description provided for @hardwareHelp.
  ///
  /// In en, this message translates to:
  /// **'Pair the scanner and printer in Android Bluetooth settings first. Sales still work without them — type barcodes manually and reprint receipts from history.'**
  String get hardwareHelp;

  /// No description provided for @barcodeScanner.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanner'**
  String get barcodeScanner;

  /// No description provided for @receiptPrinter.
  ///
  /// In en, this message translates to:
  /// **'Receipt printer'**
  String get receiptPrinter;

  /// No description provided for @hardwareTestsLater.
  ///
  /// In en, this message translates to:
  /// **'Use Test Scanner and Test Printer after pairing in Android Bluetooth settings.'**
  String get hardwareTestsLater;

  /// No description provided for @testScanner.
  ///
  /// In en, this message translates to:
  /// **'Test Scanner'**
  String get testScanner;

  /// No description provided for @testPrinter.
  ///
  /// In en, this message translates to:
  /// **'Test Printer'**
  String get testPrinter;

  /// No description provided for @scannerTestWaiting.
  ///
  /// In en, this message translates to:
  /// **'Scanner ready — scan a barcode…'**
  String get scannerTestWaiting;

  /// No description provided for @scannerTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Scanner OK — read {barcode}'**
  String scannerTestSuccess(String barcode);

  /// No description provided for @scannerTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Scanner test failed — pair in Bluetooth settings, then try again.'**
  String get scannerTestFailed;

  /// No description provided for @printerTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Test receipt sent to the printer.'**
  String get printerTestSuccess;

  /// No description provided for @printerTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed — check the printer and try again.'**
  String get printerTestFailed;

  /// No description provided for @printerTestDisconnected.
  ///
  /// In en, this message translates to:
  /// **'No printer connected — pair in Bluetooth settings, then try again.'**
  String get printerTestDisconnected;

  /// No description provided for @printerTestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Printer did not respond — check power and try again.'**
  String get printerTestTimeout;

  /// No description provided for @printerTestPaperOut.
  ///
  /// In en, this message translates to:
  /// **'Printer is out of paper — add paper and try again.'**
  String get printerTestPaperOut;

  /// No description provided for @hardwareHidHint.
  ///
  /// In en, this message translates to:
  /// **'The scanner acts like a keyboard. After Test Scanner, scan any barcode to confirm.'**
  String get hardwareHidHint;

  /// No description provided for @hardwareConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get hardwareConnecting;

  /// No description provided for @changePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePinTitle;

  /// No description provided for @changePinHelp.
  ///
  /// In en, this message translates to:
  /// **'Your PIN unlocks this device. It stays on the device and is never sent to the server.'**
  String get changePinHelp;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN *'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN *'**
  String get newPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN *'**
  String get confirmNewPin;

  /// No description provided for @pinHint.
  ///
  /// In en, this message translates to:
  /// **'4–8 digits'**
  String get pinHint;

  /// No description provided for @savePin.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get savePin;

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved on this device.'**
  String get pinSaved;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'New PIN and confirmation do not match.'**
  String get pinMismatch;

  /// No description provided for @pinInvalid.
  ///
  /// In en, this message translates to:
  /// **'New PIN must be 4 to 8 digits.'**
  String get pinInvalid;

  /// No description provided for @pinChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change PIN. Check your current PIN and try again.'**
  String get pinChangeFailed;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up this device'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Complete these steps before the shop opens. You can skip optional items, but do not skip them on both devices.'**
  String get setupIntro;

  /// No description provided for @setupDeviceName.
  ///
  /// In en, this message translates to:
  /// **'1. Device name'**
  String get setupDeviceName;

  /// No description provided for @setupDeviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Counter tablet)'**
  String get setupDeviceNameHint;

  /// No description provided for @setupHardware.
  ///
  /// In en, this message translates to:
  /// **'2. Hardware checklist'**
  String get setupHardware;

  /// No description provided for @setupScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanner paired to this device'**
  String get setupScannerTitle;

  /// No description provided for @setupScannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pair in Android Bluetooth settings, then confirm here.'**
  String get setupScannerSubtitle;

  /// No description provided for @setupPrinterTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt printer paired to this device'**
  String get setupPrinterTitle;

  /// No description provided for @setupPrinterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional at launch — skip if you have no printer yet.'**
  String get setupPrinterSubtitle;

  /// No description provided for @setupOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Other device (tablet or phone) also set up'**
  String get setupOtherTitle;

  /// No description provided for @setupOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both devices must be paired and signed in before opening day.'**
  String get setupOtherSubtitle;

  /// No description provided for @openHardwareStatus.
  ///
  /// In en, this message translates to:
  /// **'Open hardware status'**
  String get openHardwareStatus;

  /// No description provided for @setupSync.
  ///
  /// In en, this message translates to:
  /// **'3. Sync catalog'**
  String get setupSync;

  /// No description provided for @setupSyncEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products on this device yet. Sync now after the catalog was imported on the dashboard.'**
  String get setupSyncEmpty;

  /// No description provided for @setupSyncReady.
  ///
  /// In en, this message translates to:
  /// **'{count} products ready. Pending sync: {pending}.'**
  String setupSyncReady(int count, int pending);

  /// No description provided for @setupActivePos.
  ///
  /// In en, this message translates to:
  /// **'4. Active POS'**
  String get setupActivePos;

  /// No description provided for @setupActivePosHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark this device as the shop’s active POS, or skip if this is the standby phone.'**
  String get setupActivePosHelp;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get finishSetup;

  /// No description provided for @finishSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Mark or skip every checklist item before finishing.'**
  String get finishSetupHint;

  /// No description provided for @needed.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get needed;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @syncFinished.
  ///
  /// In en, this message translates to:
  /// **'Sync finished.'**
  String get syncFinished;

  /// No description provided for @couldNotSync.
  ///
  /// In en, this message translates to:
  /// **'Could not sync. Check the connection and try again — you can still finish setup.'**
  String get couldNotSync;

  /// No description provided for @nameSavedLocal.
  ///
  /// In en, this message translates to:
  /// **'Name saved on this device. It will update on the server when online.'**
  String get nameSavedLocal;

  /// No description provided for @enterDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a device name.'**
  String get enterDeviceName;

  /// No description provided for @productForm.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productForm;

  /// No description provided for @newProduct.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get newProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @priceMmk.
  ///
  /// In en, this message translates to:
  /// **'Price (MMK) *'**
  String get priceMmk;

  /// No description provided for @costPriceMmk.
  ///
  /// In en, this message translates to:
  /// **'Cost price (MMK)'**
  String get costPriceMmk;

  /// No description provided for @costPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Add cost price to see profit in reports'**
  String get costPriceHint;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @newCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Or type a new category name'**
  String get newCategoryName;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @lowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert at'**
  String get lowStockThreshold;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save product'**
  String get saveProduct;

  /// No description provided for @activeProduct.
  ///
  /// In en, this message translates to:
  /// **'Active (sellable)'**
  String get activeProduct;

  /// No description provided for @couldNotSaveProduct.
  ///
  /// In en, this message translates to:
  /// **'Could not save the product. Try again.'**
  String get couldNotSaveProduct;

  /// No description provided for @printerNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Printer not connected — sale is saved. Reprint from history later.'**
  String get printerNotConnected;

  /// No description provided for @printingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Sending to printer…'**
  String get printingReceipt;

  /// No description provided for @ago1d.
  ///
  /// In en, this message translates to:
  /// **'1d ago'**
  String get ago1d;

  /// No description provided for @agoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String agoHours(int hours);

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @completeSale.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE SALE'**
  String get completeSale;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Payment: CASH'**
  String get paymentCash;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found — try a different name'**
  String get noProductsFound;

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock {stock}'**
  String stockLabel(int stock);

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete product'**
  String get deleteProduct;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this product?'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductBody.
  ///
  /// In en, this message translates to:
  /// **'It will be hidden from selling. Past sales stay in history.'**
  String get deleteProductBody;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @quantityRequired.
  ///
  /// In en, this message translates to:
  /// **'Quantity *'**
  String get quantityRequired;

  /// No description provided for @noteRequired.
  ///
  /// In en, this message translates to:
  /// **'Note *'**
  String get noteRequired;

  /// No description provided for @categoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryRequired;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Amount (MMK) *'**
  String get amountRequired;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @enterBarcode.
  ///
  /// In en, this message translates to:
  /// **'Enter a barcode.'**
  String get enterBarcode;

  /// No description provided for @noStaffPinsYet.
  ///
  /// In en, this message translates to:
  /// **'No staff PINs on this device yet. Sign in online once to download them.'**
  String get noStaffPinsYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

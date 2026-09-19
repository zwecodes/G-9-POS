// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appTitle => 'G9POS';

  @override
  String get navPos => 'ရောင်းရန်';

  @override
  String get navProducts => 'ပစ္စည်းများ';

  @override
  String get navReports => 'အစီရင်ခံစာ';

  @override
  String get navSettings => 'ဆက်တင်';

  @override
  String get language => 'ဘာသာစကား';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMyanmar => 'မြန်မာ';

  @override
  String get signIn => 'ဝင်မည်';

  @override
  String get signInToDevice => 'ဤစက်သို့ ဝင်ရောက်ပါ';

  @override
  String get username => 'အသုံးပြုသူအမည်';

  @override
  String get password => 'စကားဝှက်';

  @override
  String get unlockWithPin => 'PIN ဖြင့် ဖွင့်မည်';

  @override
  String get unlockThisDevice => 'ဤစက်ကို ဖွင့်မည်';

  @override
  String get whoIsSelling => 'ဘယ်သူ ရောင်းနေသလဲ?';

  @override
  String get continueLabel => 'ဆက်လုပ်မည်';

  @override
  String get unlock => 'ဖွင့်မည်';

  @override
  String get pin => 'PIN';

  @override
  String get couldNotLoadStaff => 'ဝန်ထမ်းစာရင်း မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get offlineBanner =>
      'အင်တာနက် မရှိ — ရောင်းချမှုများကို ဤစက်တွင် သိမ်းထားသည်';

  @override
  String get syncStatus => 'ချိတ်ဆက်မှု အခြေအနေ';

  @override
  String get syncNow => 'ယခု ချိတ်ဆက်မည်';

  @override
  String pendingItems(int count) {
    return 'စောင့်ဆိုင်းနေသော အချက်အလက်: $count';
  }

  @override
  String get notSyncedYet => 'မချိတ်ဆက်ရသေးပါ';

  @override
  String lastSynced(String when) {
    return 'နောက်ဆုံး ချိတ်ဆက်ချိန် $when';
  }

  @override
  String get notices => 'အသိပေးချက်များ';

  @override
  String get noSyncProblems => 'ချိတ်ဆက်မှု ပြဿနာ မရှိပါ။';

  @override
  String get syncStaleDay =>
      'ချိတ်ဆက်မှု တစ်ရက်ကျော် ကြာနေပါပြီ။ အင်တာနက် ရရင် ချိတ်ဆက်ပါ။';

  @override
  String syncStaleHours(int hours) {
    return 'နောက်ဆုံး ချိတ်ဆက်မှု $hours နာရီခန့် ကြာပါပြီ။ ရောင်းချနိုင်ဆဲ ဖြစ်သည်။';
  }

  @override
  String get syncStaleFewHours =>
      'ချိတ်ဆက်မှု နာရီအနည်းငယ် ကြာနေပါပြီ။ ရောင်းချနိုင်ဆဲ ဖြစ်သည်။';

  @override
  String get products => 'ပစ္စည်းများ';

  @override
  String get categories => 'အမျိုးအစားများ';

  @override
  String get inventory => 'လက်ကျန်ပစ္စည်း';

  @override
  String get addProduct => 'ပစ္စည်း ထည့်မည်';

  @override
  String get noProductsYet => 'ပစ္စည်း မရှိသေးပါ — ပထမဆုံး ပစ္စည်း ထည့်ပါ';

  @override
  String get couldNotLoadProducts => 'ပစ္စည်းစာရင်း မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get reports => 'အစီရင်ခံစာ';

  @override
  String get reportsOwnerOnly => 'အစီရင်ခံစာကို ပိုင်ရှင်သာ ကြည့်နိုင်သည်။';

  @override
  String get today => 'ယနေ့';

  @override
  String get thisWeek => 'ဤအပတ်';

  @override
  String get custom => 'စိတ်ကြိုက်';

  @override
  String get revenue => 'ဝင်ငွေ';

  @override
  String get profit => 'အမြတ်';

  @override
  String get incompleteProfit => 'မပြည့်စုံ — အမြတ်မြင်ရန် ကုန်ကျစရိတ် ထည့်ပါ';

  @override
  String get sales => 'ရောင်းချမှု';

  @override
  String get itemsSold => 'ရောင်းခဲ့သော အရေအတွက်';

  @override
  String get topProducts => 'အရောင်းရဆုံး ပစ္စည်းများ';

  @override
  String get noSalesInPeriod => 'ဤကာလတွင် ရောင်းချမှု မရှိပါ။';

  @override
  String get expenses => 'အသုံးစရိတ်';

  @override
  String get noExpensesInPeriod => 'ဤကာလတွင် အသုံးစရိတ် မရှိပါ။';

  @override
  String get total => 'စုစုပေါင်း';

  @override
  String get couldNotLoadReport => 'အစီရင်ခံစာ မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get settings => 'ဆက်တင်';

  @override
  String get salesHistory => 'ရောင်းချမှု မှတ်တမ်း';

  @override
  String get thisDevice => 'ဤစက်';

  @override
  String get deviceSetupChecklist => 'စက် တပ်ဆင် စစ်ဆေးစာရင်း';

  @override
  String get hardware => 'စက်ပစ္စည်း';

  @override
  String get changePin => 'PIN ပြောင်းမည်';

  @override
  String get lockScreen => 'စက် သော့ခတ်မည်';

  @override
  String get signOut => 'ထွက်မည်';

  @override
  String get signedIn => 'ဝင်ထားသည်';

  @override
  String get signOutConfirmTitle => 'ထွက်မလား?';

  @override
  String get signOutConfirmBody =>
      'ဤစက်ကို ပြန်သုံးရန် ပိုင်ရှင် စကားဝှက် လိုအပ်ပါမည်။';

  @override
  String get stay => 'နေမည်';

  @override
  String get cancel => 'မလုပ်တော့';

  @override
  String get save => 'သိမ်းမည်';

  @override
  String get delete => 'ဖျက်မည်';

  @override
  String get keep => 'ထားမည်';

  @override
  String get done => 'ပြီးပြီ';

  @override
  String get skip => 'ကျော်မည်';

  @override
  String get checkout => 'ငွေရှင်းမည်';

  @override
  String get saleComplete => 'ရောင်းချမှု ပြီးပါပြီ';

  @override
  String get newSale => 'ရောင်းချမှု အသစ်';

  @override
  String get cartEmpty => 'ပစ္စည်း စကန်ဖတ်ပါ သို့မဟုတ် အပေါ်တွင် ရှာပါ';

  @override
  String get searchProducts => 'ပစ္စည်း ရှာမည်';

  @override
  String get typeBarcode => 'ဘားကုဒ် ရိုက်ထည့်မည်';

  @override
  String get addToCart => 'ထည့်မည်';

  @override
  String get payCash => 'ငွေလက်ခံမည်';

  @override
  String get couldNotCompleteSale => 'ရောင်းချမှု မပြီးနိုင်ပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get ownerOnly => 'ပိုင်ရှင်သာ လုပ်နိုင်သည်။';

  @override
  String get inventoryOwnerOnly =>
      'လက်ကျန်ပစ္စည်းကို ပိုင်ရှင်သာ ကြည့်နိုင်သည်။';

  @override
  String get couldNotLoadStock => 'လက်ကျန် မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String allStock(int count) {
    return 'အားလုံး ($count)';
  }

  @override
  String lowStock(int count) {
    return 'နည်းနေသည် ($count)';
  }

  @override
  String outOfStock(int count) {
    return 'ကုန်နေသည် ($count)';
  }

  @override
  String get noProductsStock => 'ပစ္စည်း မရှိသေးပါ။';

  @override
  String get noLowStock => 'နည်းနေသော ပစ္စည်း မရှိပါ။';

  @override
  String get noOutOfStock => 'ကုန်နေသော ပစ္စည်း မရှိပါ။';

  @override
  String get adjustStock => 'လက်ကျန် ပြင်မည်';

  @override
  String get stockOwnerOnly => 'ပိုင်ရှင်သာ လက်ကျန် ပြင်နိုင်သည်။';

  @override
  String get addStock => '+ လက်ကျန် တိုးမည်';

  @override
  String get removeStock => '- လက်ကျန် လျှော့မည်';

  @override
  String get whyStockChanging => 'ဘာကြောင့် ပြောင်းသလဲ?';

  @override
  String get saveStockChange => 'လက်ကျန် ပြောင်းလဲမှု သိမ်းမည်';

  @override
  String currentStock(int stock) {
    return 'လက်ရှိ လက်ကျန်: $stock';
  }

  @override
  String get addExpense => 'အသုံးစရိတ် ထည့်မည်';

  @override
  String get saveExpense => 'အသုံးစရိတ် သိမ်းမည်';

  @override
  String dateLabel(String date) {
    return 'နေ့ရက်: $date';
  }

  @override
  String get noExpensesYet => 'ယနေ့ အသုံးစရိတ် မရှိသေးပါ';

  @override
  String get couldNotLoadExpenses => 'အသုံးစရိတ် မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get noSalesToday => 'ယနေ့ ရောင်းချမှု မရှိသေးပါ';

  @override
  String get couldNotLoadSales => 'ရောင်းချမှု မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get cancelled => 'ပယ်ဖျက်ပြီး';

  @override
  String get cancelThisSale => 'ဤရောင်းချမှု ပယ်ဖျက်မည်';

  @override
  String get cancelSaleTitle => 'ဤရောင်းချမှု ပယ်ဖျက်မလား?';

  @override
  String get cancelSaleBody =>
      'လက်ကျန် ပြန်တက်ပါမည်။ ယနေ့ ရောင်းချမှုများအတွက်သာ လုပ်နိုင်သည်။';

  @override
  String get saleUnavailable => 'ထိုရောင်းချမှု မရှိတော့ပါ။';

  @override
  String get reprintReceipt => 'ဘောင်ချာ ပြန်ထုတ်မည်';

  @override
  String get categoriesTitle => 'အမျိုးအစားများ';

  @override
  String get categoriesOwnerOnly => 'ပိုင်ရှင်သာ အမျိုးအစား စီမံနိုင်သည်။';

  @override
  String get noCategoriesYet => 'အမျိုးအစား မရှိသေးပါ — ပထမဆုံး ထည့်ပါ';

  @override
  String get addCategory => 'အမျိုးအစား ထည့်မည်';

  @override
  String get editCategory => 'အမျိုးအစား ပြင်မည်';

  @override
  String get nameRequired => 'အမည် *';

  @override
  String get deleteCategoryTitle => 'ဤအမျိုးအစား ဖျက်မလား?';

  @override
  String deleteCategoryBody(String name) {
    return '\"$name\" ကို ဖယ်ရှားပါမည်။ အတွင်းရှိ ပစ္စည်းများကို အရင် ရွှေ့ပါ။';
  }

  @override
  String get couldNotLoadCategories => 'အမျိုးအစား မရပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get couldNotSaveCategory => 'အမျိုးအစား မသိမ်းနိုင်ပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get couldNotDeleteCategory =>
      'အမျိုးအစား မဖျက်နိုင်ပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get deviceSettingsOwnerOnly =>
      'ပိုင်ရှင်သာ စက်ဆက်တင် ပြောင်းနိုင်သည်။';

  @override
  String deviceId(String id) {
    return 'စက် ID: $id';
  }

  @override
  String get deviceName => 'စက်အမည် *';

  @override
  String get saveName => 'အမည် သိမ်းမည်';

  @override
  String get activePos => 'အသုံးပြုနေသော POS';

  @override
  String get activePosHelp =>
      'ဤတက်ဘလက် သို့မဟုတ် ဖုန်းကို ဆိုင်၏ အဓိက POS အဖြစ် သတ်မှတ်ပါ။ အင်တာနက် မရှိလည်း လုပ်နိုင်သည် — ချိတ်ဆက်ရင် တင်ပို့ပါမည်။';

  @override
  String get makeActivePos => 'ဤစက်ကို အဓိက POS လုပ်မည်';

  @override
  String get deviceNameSaved => 'စက်အမည် သိမ်းပြီးပါပြီ။';

  @override
  String get activePosQueued =>
      'နောက်ဆုံးအောင်မြင်သော ချိတ်ဆက်မှုအပြီး ဤစက်သည် အဓိက POS ဖြစ်ပါမည်။';

  @override
  String get hardwareTitle => 'စက်ပစ္စည်း';

  @override
  String get hardwareHelp =>
      'စကန်နာနှင့် ပရင်တာ မချိတ်ရသေးပါ။ ရောင်းချမှု လုပ်နိုင်ဆဲ — ဘားကုဒ် ရိုက်ထည့်နိုင်ပြီး နောက်မှ မှတ်တမ်းမှ ဘောင်ချာ ပြန်ထုတ်နိုင်သည်။';

  @override
  String get barcodeScanner => 'ဘားကုဒ် စကန်နာ';

  @override
  String get receiptPrinter => 'ဘောင်ချာ ပရင်တာ';

  @override
  String get hardwareTestsLater =>
      'ဘလူးတုသ် ချိတ်ဆက်မှု ထည့်ပြီးမှ စမ်းသပ် ခလုတ်များ ပေါ်ပါမည်။';

  @override
  String get changePinTitle => 'PIN ပြောင်းမည်';

  @override
  String get changePinHelp =>
      'သင့် PIN သည် ဤစက်ကို ဖွင့်ရန်ဖြစ်သည်။ စက်ပေါ်တွင်သာ ရှိပြီး ဆာဗာသို့ မပို့ပါ။';

  @override
  String get currentPin => 'လက်ရှိ PIN *';

  @override
  String get newPin => 'PIN အသစ် *';

  @override
  String get confirmNewPin => 'PIN အသစ် အတည်ပြု *';

  @override
  String get pinHint => 'ဂဏန်း ၄–၈ လုံး';

  @override
  String get savePin => 'PIN သိမ်းမည်';

  @override
  String get pinSaved => 'PIN ကို ဤစက်တွင် သိမ်းပြီးပါပြီ။';

  @override
  String get pinMismatch => 'PIN အသစ်နှင့် အတည်ပြုချက် မတူညီပါ။';

  @override
  String get pinInvalid => 'PIN အသစ်သည် ဂဏန်း ၄ မှ ၈ လုံး ဖြစ်ရမည်။';

  @override
  String get pinChangeFailed =>
      'PIN မပြောင်းနိုင်ပါ။ လက်ရှိ PIN စစ်ပြီး ထပ်ကြိုးစားပါ။';

  @override
  String get setupTitle => 'ဤစက်ကို တပ်ဆင်မည်';

  @override
  String get setupIntro =>
      'ဆိုင်မဖွင့်မီ ဤအဆင့်များ ပြီးအောင်လုပ်ပါ။ မဖြစ်မနေ မဟုတ်သော အချက်များကို ကျော်နိုင်သော်လည်း စက်နှစ်လုံးစလုံးတွင် မကျော်ပါနှင့်။';

  @override
  String get setupDeviceName => '၁။ စက်အမည်';

  @override
  String get setupDeviceNameHint => 'အမည် (ဥပမာ ကောင်တာ တက်ဘလက်)';

  @override
  String get setupHardware => '၂။ စက်ပစ္စည်း စစ်ဆေးစာရင်း';

  @override
  String get setupScannerTitle => 'ဘားကုဒ် စကန်နာကို ဤစက်နှင့် ချိတ်ပြီး';

  @override
  String get setupScannerSubtitle =>
      'Android ဘလူးတုသ် ဆက်တင်တွင် ချိတ်ပြီး ဤနေရာတွင် အတည်ပြုပါ။';

  @override
  String get setupPrinterTitle => 'ဘောင်ချာ ပရင်တာကို ဤစက်နှင့် ချိတ်ပြီး';

  @override
  String get setupPrinterSubtitle =>
      'ဖွင့်ချိန်တွင် မဖြစ်မနေ မဟုတ် — ပရင်တာ မရှိသေးရင် ကျော်ပါ။';

  @override
  String get setupOtherTitle => 'အခြားစက် (တက်ဘလက် သို့ ဖုန်း) လည်း တပ်ဆင်ပြီး';

  @override
  String get setupOtherSubtitle =>
      'ဆိုင်မဖွင့်မီ စက်နှစ်လုံးစလုံး ချိတ်ပြီး ဝင်ထားရမည်။';

  @override
  String get openHardwareStatus => 'စက်ပစ္စည်း အခြေအနေ ဖွင့်မည်';

  @override
  String get setupSync => '၃။ ကတ်တလောက် ချိတ်ဆက်မည်';

  @override
  String get setupSyncEmpty =>
      'ဤစက်တွင် ပစ္စည်း မရှိသေးပါ။ ဒက်ရှ်ဘုတ်မှ ကတ်တလောက် တင်ပြီးနောက် ချိတ်ဆက်ပါ။';

  @override
  String setupSyncReady(int count, int pending) {
    return 'ပစ္စည်း $count ခု အဆင်သင့်။ စောင့်ဆိုင်းနေ: $pending။';
  }

  @override
  String get setupActivePos => '၄။ အဓိက POS';

  @override
  String get setupActivePosHelp =>
      'ဤစက်ကို ဆိုင်၏ အဓိက POS လုပ်ပါ၊ သို့မဟုတ် အရန်ဖုန်းဆိုရင် ကျော်ပါ။';

  @override
  String get finishSetup => 'တပ်ဆင်မှု ပြီးမည်';

  @override
  String get finishSetupHint =>
      'မပြီးမီ စစ်ဆေးစာရင်း အားလုံးကို ပြီးပြီ သို့မဟုတ် ကျော်မည် လုပ်ပါ။';

  @override
  String get needed => 'လိုအပ်သည်';

  @override
  String get skipped => 'ကျော်ပြီး';

  @override
  String get syncFinished => 'ချိတ်ဆက်မှု ပြီးပါပြီ။';

  @override
  String get couldNotSync =>
      'မချိတ်ဆက်နိုင်ပါ။ အင်တာနက် စစ်ပြီး ထပ်ကြိုးစားပါ — တပ်ဆင်မှု ပြီးနိုင်ဆဲ ဖြစ်သည်။';

  @override
  String get nameSavedLocal =>
      'အမည်ကို ဤစက်တွင် သိမ်းပြီးပါပြီ။ အွန်လိုင်း ရရင် ဆာဗာတွင် အပ်ဒိတ်လုပ်ပါမည်။';

  @override
  String get enterDeviceName => 'စက်အမည် ထည့်ပါ။';

  @override
  String get productForm => 'ပစ္စည်း';

  @override
  String get newProduct => 'ပစ္စည်း အသစ်';

  @override
  String get editProduct => 'ပစ္စည်း ပြင်မည်';

  @override
  String get priceMmk => 'ဈေးနှုန်း (ကျပ်) *';

  @override
  String get costPriceMmk => 'ကုန်ကျစရိတ် (ကျပ်)';

  @override
  String get costPriceHint => 'အမြတ်မြင်ရန် ကုန်ကျစရိတ် ထည့်ပါ';

  @override
  String get barcode => 'ဘားကုဒ်';

  @override
  String get category => 'အမျိုးအစား';

  @override
  String get newCategoryName => 'သို့မဟုတ် အမျိုးအစားအမည် အသစ် ရိုက်ပါ';

  @override
  String get unit => 'ယူနစ်';

  @override
  String get lowStockThreshold => 'လက်ကျန် နည်းသတိပေး အရေအတွက်';

  @override
  String get saveProduct => 'ပစ္စည်း သိမ်းမည်';

  @override
  String get activeProduct => 'အသုံးပြုနိုင် (ရောင်းနိုင်)';

  @override
  String get couldNotSaveProduct => 'ပစ္စည်း မသိမ်းနိုင်ပါ။ ထပ်ကြိုးစားပါ။';

  @override
  String get printerNotConnected =>
      'ပရင်တာ မချိတ်ရသေး — ရောင်းချမှု သိမ်းပြီးပါပြီ။ နောက်မှ မှတ်တမ်းမှ ပြန်ထုတ်ပါ။';

  @override
  String get printingReceipt => 'ပရင်တာသို့ ပို့နေသည်…';

  @override
  String get ago1d => '၁ ရက်ကြာ';

  @override
  String agoHours(int hours) {
    return '$hours နာရီကြာ';
  }

  @override
  String get cart => 'ခြင်းတောင်း';

  @override
  String get completeSale => 'ရောင်းချမှု ပြီးမည်';

  @override
  String get paymentCash => 'ငွေပေးချေမှု: ငွေသား';

  @override
  String get quantity => 'အရေအတွက်';

  @override
  String get set => 'သတ်မှတ်မည်';

  @override
  String get noProductsFound => 'ပစ္စည်း မတွေ့ပါ — အခြားအမည် စမ်းပါ';

  @override
  String stockLabel(int stock) {
    return 'လက်ကျန် $stock';
  }

  @override
  String get none => 'မရှိ';

  @override
  String get deleteProduct => 'ပစ္စည်း ဖျက်မည်';

  @override
  String get deleteProductTitle => 'ဤပစ္စည်း ဖျက်မလား?';

  @override
  String get deleteProductBody =>
      'ရောင်းစာရင်းမှ ပုန်းသွားပါမည်။ အရောင်းမှတ်တမ်း မပျက်ပါ။';

  @override
  String get keepIt => 'ထားမည်';

  @override
  String get quantityRequired => 'အရေအတွက် *';

  @override
  String get noteRequired => 'မှတ်ချက် *';

  @override
  String get categoryRequired => 'အမျိုးအစား *';

  @override
  String get amountRequired => 'ပမာဏ (ကျပ်) *';

  @override
  String get noteOptional => 'မှတ်ချက် (မဖြစ်မနေ မဟုတ်)';

  @override
  String get reason => 'အကြောင်းရင်း';

  @override
  String get enterBarcode => 'ဘားကုဒ် ထည့်ပါ။';

  @override
  String get noStaffPinsYet =>
      'ဤစက်တွင် ဝန်ထမ်း PIN မရှိသေးပါ။ တစ်ကြိမ် အွန်လိုင်းဝင်ပြီး ဆွဲယူပါ။';
}

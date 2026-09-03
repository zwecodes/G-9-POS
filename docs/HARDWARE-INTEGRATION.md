# HARDWARE-INTEGRATION.md

**Version:** 1.0  
**Status:** Complete — 0 open questions  
**Last updated:** 2026-09-01  
**Author:** Architecture Team

---

## 1. Overview

G9POS integrates three categories of Bluetooth hardware:

| Device | Model | Connection | Status |
|--------|-------|-----------|--------|
| Barcode Scanner | Netum NT-1228BL (or Eyoyo EY-015) | Bluetooth HID | Launch |
| Receipt Printer | GOOJPRT PT-210 or Xprinter XP-P300 | Bluetooth SPP / ESC-POS | Launch |
| Label Printer | NIIMBOT B21 | Bluetooth (NIIMBOT SDK) | Post-launch |

All hardware is optional at the app level. G9POS operates fully without any Bluetooth device — manual barcode entry and no-receipt mode are always available as fallbacks.

---

## 2. Design Principles

1. **A sale must never be blocked by hardware.** Scanner disconnected, printer out of paper, printer offline — none of these prevent a sale from completing. Hardware failure is a UI concern, not a business logic concern.
2. **Hardware is pluggable.** Each device type is accessed through a Flutter abstraction interface. Swapping brands means swapping one implementation class, nothing else.
3. **All hardware communication is async.** No hardware call ever blocks the main thread or the sale completion flow.
4. **Pair both devices during setup.** The tablet (primary POS) and phone (hot standby) must both be paired to the printer and scanner during initial shop setup — not at failover time. Failover must be instant; re-pairing mid-crisis is not acceptable.

---

## 3. Hardware Abstraction Layer (HAL)

All hardware lives behind interfaces in `apps/mobile/lib/core/hardware/`. Business logic (cart, sale completion, inventory) never imports a concrete hardware class — only the interface.

```
core/hardware/
  interfaces/
    scanner_interface.dart       ← defines onBarcodeScanned stream
    receipt_printer_interface.dart
    label_printer_interface.dart
  implementations/
    bluetooth_hid_scanner.dart   ← Netum NT-1228BL, Eyoyo EY-015
    escpos_printer.dart          ← GOOJPRT PT-210, Xprinter XP-P300
    niimbot_printer.dart         ← post-launch
    camera_scanner.dart          ← post-launch (mobile_scanner package)
  hardware_provider.dart         ← Riverpod providers for each interface
  hardware_status.dart           ← connection state enum for UI indicators
```

### Interface definitions

```dart
// scanner_interface.dart
abstract class ScannerInterface {
  Stream<String> get onBarcodeScanned;
  Future<bool> connect();
  Future<void> disconnect();
  bool get isConnected;
}

// receipt_printer_interface.dart
abstract class ReceiptPrinterInterface {
  Future<PrintResult> printReceipt(ReceiptData data);
  Future<bool> connect();
  Future<void> disconnect();
  bool get isConnected;
}

enum PrintResult { success, timeout, disconnected, paperOut, unknown }
```

---

## 4. Barcode Scanner Integration

### 4.1 How Bluetooth HID works

The Netum NT-1228BL connects in **Bluetooth HID mode** — it behaves exactly like a Bluetooth keyboard. When a barcode is scanned, the scanner types the barcode digits into whatever text field has focus, followed by an Enter keypress. No special driver or SDK is required.

### 4.2 Scan-vs-type detection

The POS sale screen has a barcode input field that is always focused (invisible, sits behind the UI). The app must distinguish between a human typing a barcode manually and a scanner firing characters rapidly.

**Rule:** If all characters of an input arrive within **100ms total**, treat it as a scanner scan. If any character gap exceeds 100ms, treat it as manual typing.

```dart
// core/hardware/implementations/bluetooth_hid_scanner.dart

const int kScanThresholdMs = 100; // configurable constant — tune after real hardware testing

class BluetoothHIDScanner implements ScannerInterface {
  final _controller = StreamController<String>.broadcast();
  final _buffer = StringBuffer();
  Timer? _debounce;

  @override
  Stream<String> get onBarcodeScanned => _controller.stream;

  void onKeyInput(String char) {
    _buffer.write(char);
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: kScanThresholdMs), () {
      final result = _buffer.toString().trim();
      _buffer.clear();
      if (result.isNotEmpty) {
        _controller.add(result); // emits barcode string to business logic
      }
    });
  }
}
```

**Why 100ms:** The Netum NT-1228BL sends characters with small inter-character delays. On a mid-range Android tablet under load (Drift queries running, UI animating), character delivery can spread beyond 50ms. 100ms is the real-world threshold used by production POS apps for Bluetooth HID — fast enough that no human typist triggers it, slow enough that the scanner is never misread as manual input. `kScanThresholdMs` is a single named constant — if hardware testing reveals a better value, one line changes, nothing else.

### 4.3 Scanner failure handling

| Failure | App behaviour |
|---------|--------------|
| Scanner not paired | Settings screen shows "No scanner connected" — sale screen shows manual entry field |
| Scanner disconnects mid-session | Manual barcode entry field appears automatically — no interruption to sale |
| Barcode not found in products | Toast: "Product not found — check barcode or search by name" |
| Partial scan (corrupted read) | Barcode fails product lookup — treated as not found |

### 4.4 Manual barcode entry fallback

When the scanner is not connected, the POS sale screen shows a visible text input field with a keyboard icon. The owner types the barcode manually and taps Enter or the search button. The same product lookup logic runs — the scanner and manual entry paths converge at the same `onBarcodeScanned` stream.

### 4.5 Initial setup

1. Open Android Bluetooth settings on the tablet.
2. Put Netum NT-1228BL into pairing mode (hold button until LED flashes).
3. Pair from Android settings.
4. Open G9POS → Settings → Hardware → Test Scanner.
5. Scan any barcode — confirmation appears if working.
6. **Repeat steps 1–5 on the standby phone.** Both devices must be paired before the shop opens.

---

## 5. Receipt Printer Integration

### 5.1 How Bluetooth SPP + ESC-POS works

The GOOJPRT PT-210 and Xprinter XP-P300 connect via **Bluetooth SPP (Serial Port Profile)**. The app sends raw ESC/POS command bytes over the SPP socket. ESC/POS is a standard thermal printer protocol — the same commands work on both printer models.

Flutter package: `flutter_bluetooth_serial` for the SPP connection, `esc_pos_utils` for building ESC/POS byte sequences.

### 5.2 Receipt layout (58mm paper)

**Resolved: 58mm paper width.** Reasons: cheaper rolls, widely available in Myanmar, smaller printer footprint on a tight shop counter, sufficient for G9POS receipt content. All ESC/POS layout is designed for 58mm — do not add 80mm support unless explicitly requested later.

58mm thermal paper at standard resolution = **32 characters per line** in normal font.

```
================================  (32 chars)
        G9POS RECEIPT
  Pin Laung Motorcycle Parts
================================
Date: 2026-07-18  Time: 14:32
Sale: S-00142
--------------------------------
Yamaha Oil Filter YZ250   x2
                     16,000 MMK
Chain Lube 400ml          x1
                      4,500 MMK
--------------------------------
TOTAL:               20,500 MMK
PAYMENT: CASH
CHANGE:                   0 MMK
--------------------------------
     Thank you for shopping!
================================
```

### 5.3 Print flow

```
Sale completes (local SQLite write + sync queue)
        │
        ▼
Receipt data built from sale record (never re-fetched from server)
        │
        ▼
Is printer connected?
  ├── Yes → send ESC/POS bytes over SPP
  │           ├── Success → done
  │           ├── Timeout (3s) → show "Print failed — reprint from history"
  │           └── Paper out → show "Add paper — reprint from history"
  └── No  → show "No printer — reprint from history when ready"
        │
        ▼ (in all cases)
Sale is already saved. Reprint available from Sales History at any time.
```

**Critical rule:** The sale completion and the print are two separate steps. The sale is saved to SQLite the moment the owner taps "Complete Sale." The print is fire-and-forget after that. A print failure never rolls back or voids a sale.

### 5.4 Send timeout

**Resolved: 3 seconds.** This covers the printer warming up its thermal head (first print of the day takes longer). If testing shows a specific printer model consistently needs more, raise to 5s — but start at 3s. The timeout constant is named `kPrinterSendTimeoutSeconds` in `hardware_constants.dart`.

### 5.5 Printer failure handling

| Failure | App behaviour |
|---------|--------------|
| Printer not paired | Settings shows "No printer connected" — sale screen hides print button, sale completes normally |
| Printer disconnects mid-session | Sale completes, toast: "Receipt not printed — reprint from history" |
| Send timeout (3s) | Same as disconnect |
| Paper out | Same as disconnect — printer returns a status byte; app reads it and shows "Add paper" specifically |
| Printer busy (previous job) | Queue the next job — never send two jobs simultaneously over SPP |

### 5.6 Reprint from history

Every completed sale in the Sales History screen has a **Reprint Receipt** button. It rebuilds the ESC/POS bytes from the stored sale record and sends them. This works whether the original print succeeded or failed.

### 5.7 Initial setup

1. Open Android Bluetooth settings on the tablet.
2. Power on the printer — it enters pairing mode automatically.
3. Pair from Android settings. PIN is usually `0000` or `1234`.
4. Open G9POS → Settings → Hardware → Test Printer.
5. A test receipt prints if working.
6. **Repeat steps 1–5 on the standby phone.** Both devices must be paired to the printer before the shop opens. This is the one step that makes failover truly instant — the phone already knows the printer at the OS level.

### 5.8 Printer re-pairing after failover

Bluetooth Classic (SPP) pairing is stored per-device at the OS level. There is no way to transfer a pairing from the tablet to the phone silently. **The fix is to eliminate the problem during setup, not at failover time.**

Mandatory checklist during first-run setup:
- [ ] Printer paired to tablet — test receipt printed ✓
- [ ] Printer paired to phone — test receipt printed ✓
- [ ] Scanner paired to tablet — test scan confirmed ✓
- [ ] Scanner paired to phone — test scan confirmed ✓

This checklist is shown in the G9POS first-run setup flow. The owner cannot dismiss it without completing or explicitly skipping each item.

---

## 6. Label Printer Integration (Post-Launch)

**Resolved: NIIMBOT B21, post-launch.**

The NIIMBOT B21 is a small battery-powered Bluetooth label printer popular in Southeast Asian small shops. It uses the proprietary NIIMBOT protocol — there is no standard ESC/POS equivalent.

**Why post-launch:** Label printing is a nice-to-have that adds complexity (separate SDK, separate pairing flow, label layout design). The shop can operate without it. Ship core POS first.

**What to prepare now:** The `LabelPrinterInterface` is defined in the HAL today (see §3). The `NiimbotPrinter` implementation class is a stub that throws `UnimplementedError`. When post-launch work begins, only the implementation needs to be filled in — nothing else in the codebase changes.

Use case: print price/barcode labels for products that arrive without a manufacturer barcode. Owner scans the printed label with the scanner from day one.

---

## 7. Camera Scanning (Post-Launch)

**Resolved: Yes, build post-launch. HAL already supports it.**

A `CameraScanner` implementation using the `mobile_scanner` Flutter package (MLKit under the hood, well maintained, works on Android and iOS) will be added after launch without touching any business logic. It plugs into the existing `ScannerInterface`.

Use case: scanner battery dies, scanner is lost, or owner wants to use the phone camera temporarily.

**What to prepare now:** `CameraScanner` is a stub class in the HAL today. When post-launch work begins, implement `onBarcodeScanned` using `mobile_scanner`'s barcode stream. The POS screen requires zero changes.

---

## 8. Cash Drawer (Explicitly Not Supported)

**Resolved: No cash drawer support, not at launch, not post-launch unless explicitly reconsidered.**

Reasons:
- The shop is operated by one trusted person — cash drawer is a theft-prevention tool with no benefit at this scale.
- Adding it requires cash drawer open events, expected-vs-actual cash reconciliation, and report changes — non-trivial scope for no real benefit.
- The supported printer models (GOOJPRT PT-210, Xprinter XP-P300) have RJ11 cash drawer ports and support the `ESC p` command — the hardware side would be trivial if needed later. The decision is about scope, not technical difficulty.

If the shop ever hires staff that the owner doesn't fully trust, reconsider at that point.

---

## 9. Hardware Status in the UI

The app shows a hardware status indicator in the Settings screen and a subtle icon in the POS screen header.

```dart
enum HardwareStatus { connected, disconnected, notPaired }

// Shown in POS header (subtle, non-blocking):
// 🟢 scanner icon = connected
// ⚪ scanner icon = disconnected (manual entry available)
// 🟢 printer icon = connected
// ⚪ printer icon = disconnected (reprint from history available)
```

No popups or blocking alerts for hardware status in the POS screen. The owner is mid-sale — status icons are enough. Full detail and reconnect options are in Settings → Hardware.

---

## 10. Hardware Constants Reference

All hardware timing constants live in one file:

```dart
// core/hardware/hardware_constants.dart

/// Bluetooth HID scan-vs-type detection threshold.
/// Characters arriving within this window are treated as a scanner scan.
/// Tune after real hardware testing if needed.
const int kScanThresholdMs = 100;

/// Bluetooth SPP send timeout for receipt printer.
/// If no acknowledgement within this window, treat as print failure.
const int kPrinterSendTimeoutSeconds = 3;

/// Printer job queue delay — minimum ms between consecutive print jobs.
const int kPrinterJobIntervalMs = 500;
```

---

## 11. Resolved Decisions

| Decision | Resolution |
|----------|-----------|
| Scan-vs-type threshold | 100ms (`kScanThresholdMs`) — configurable constant, tune after hardware testing |
| Printer send-timeout | 3 seconds (`kPrinterSendTimeoutSeconds`) — raise to 5s if testing requires |
| Printer re-pairing after failover | Eliminated by mandatory dual-pairing during first-run setup checklist |
| Camera scanning fallback | Yes — post-launch, `CameraScanner` stub ready in HAL today |
| Cash drawer | No — explicitly out of scope at all phases unless reconsidered |
| Receipt paper width | 58mm — all ESC/POS layout designed for 32 chars/line |
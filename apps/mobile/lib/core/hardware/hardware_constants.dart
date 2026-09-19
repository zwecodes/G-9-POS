/// HARDWARE-INTEGRATION.md — named constants only; tune after real devices.
class HardwareConstants {
  HardwareConstants._();

  /// Inter-character window for HID scan-vs-type detection (§4.2).
  static const scanThresholdMs = 100;

  /// ESC/POS send timeout before treating print as failed (§5.4).
  static const printerSendTimeoutSeconds = 3;

  /// Minimum gap between consecutive print jobs (§5.5 / §10).
  static const printerJobIntervalMs = 500;
}

/// Bluetooth HID scan-vs-type detection threshold (§4.2 / §10).
const int kScanThresholdMs = HardwareConstants.scanThresholdMs;

/// Bluetooth SPP send timeout for receipt printer (§5.4 / §10).
const int kPrinterSendTimeoutSeconds =
    HardwareConstants.printerSendTimeoutSeconds;

/// Printer job queue delay — minimum ms between consecutive print jobs (§10).
const int kPrinterJobIntervalMs = HardwareConstants.printerJobIntervalMs;

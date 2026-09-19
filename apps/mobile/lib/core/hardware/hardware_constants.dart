/// HARDWARE-INTEGRATION.md — named constants only; tune after real devices.
class HardwareConstants {
  HardwareConstants._();

  /// Inter-character window for HID scan-vs-type detection (§4.2).
  static const scanThresholdMs = 100;

  /// ESC/POS send timeout before treating print as failed (§5.4).
  static const printerSendTimeoutSeconds = 3;
}

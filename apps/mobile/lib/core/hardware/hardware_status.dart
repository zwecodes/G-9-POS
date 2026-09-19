/// Connection state for non-blocking UI indicators.
enum HardwareConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

extension HardwareConnectionStatusLabel on HardwareConnectionStatus {
  String get label {
    switch (this) {
      case HardwareConnectionStatus.connected:
        return 'Connected';
      case HardwareConnectionStatus.disconnected:
        return 'Not connected';
      case HardwareConnectionStatus.connecting:
        return 'Connecting…';
      case HardwareConnectionStatus.error:
        return 'Error';
    }
  }

  bool get isReady => this == HardwareConnectionStatus.connected;
}

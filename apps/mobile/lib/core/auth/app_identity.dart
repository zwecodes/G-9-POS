/// Device and active PIN operator for shop-data writes.
class AppIdentity {
  AppIdentity({
    required Future<String> Function() deviceId,
    required String Function() operatorId,
    required String Function() operatorRole,
  })  : _deviceId = deviceId,
        _operatorId = operatorId,
        _operatorRole = operatorRole;

  final Future<String> Function() _deviceId;
  final String Function() _operatorId;
  final String Function() _operatorRole;

  Future<String> get deviceId => _deviceId();

  String get operatorId {
    final id = _operatorId();
    if (id.isEmpty) {
      throw StateError('Please unlock with your PIN first.');
    }
    return id;
  }

  String get operatorRole => _operatorRole();
}

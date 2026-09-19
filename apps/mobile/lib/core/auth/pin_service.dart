import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../database/app_database.dart';

/// On-device PIN unlock. Never sent to the server (API-SPEC.md §2.4).
class PinService {
  PinService({
    required AppDatabase db,
    Logger? logger,
  })  : _db = db,
        _log = logger ?? Logger();

  final AppDatabase _db;
  final Logger _log;

  /// Returns true only when the entered PIN matches the stored bcrypt hash.
  /// Wrong PIN, missing user, or a corrupt hash all return false.
  Future<bool> verifyPin(String userId, String enteredPin) async {
    try {
      final user = await _activeUser(userId);
      if (user == null) return false;
      final storedHash = user.pin;
      if (storedHash.isEmpty) return false;

      final computed = BCrypt.hashpw(enteredPin, storedHash);
      return _constantTimeEquals(computed, storedHash);
    } catch (error, stack) {
      _log.e('PIN check failed', error: error, stackTrace: stack);
      return false;
    }
  }

  Future<bool> isPinSet(String userId) async {
    try {
      final user = await _activeUser(userId);
      if (user == null) return false;
      return user.pin.isNotEmpty;
    } catch (error, stack) {
      _log.e('PIN set check failed', error: error, stackTrace: stack);
      return false;
    }
  }

  /// Local-only PIN change (REQUIREMENTS.md §5.1). Never sent to the server.
  Future<bool> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  }) async {
    try {
      if (newPin.length < 4 || newPin.length > 8) return false;
      if (!RegExp(r'^\d+$').hasMatch(newPin)) return false;
      final ok = await verifyPin(userId, currentPin);
      if (!ok) return false;
      final hash = BCrypt.hashpw(newPin, BCrypt.gensalt());
      await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
        UsersCompanion(
          pin: Value(hash),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return true;
    } catch (error, stack) {
      _log.e('PIN change failed', error: error, stackTrace: stack);
      return false;
    }
  }

  Future<User?> _activeUser(String userId) {
    return (_db.select(_db.users)
          ..where((u) => u.id.equals(userId) & u.deletedAt.isNull()))
        .getSingleOrNull();
  }

  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    final length = aBytes.length < bBytes.length ? aBytes.length : bBytes.length;
    var diff = aBytes.length ^ bBytes.length;
    for (var i = 0; i < length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }
}

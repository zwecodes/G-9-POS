import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/pin_service.dart';
import '../../../core/auth/token_cache.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';

class AuthRepository {
  AuthRepository({
    required AuthService auth,
    required PinService pins,
    required TokenCache tokens,
    required AppDatabase db,
    Logger? logger,
  })  : _auth = auth,
        _pins = pins,
        _tokens = tokens,
        _db = db,
        _log = logger ?? Logger();

  final AuthService _auth;
  final PinService _pins;
  final TokenCache _tokens;
  final AppDatabase _db;
  final Logger _log;

  Future<void> login(String username, String password) =>
      _auth.login(username, password);

  Future<void> refreshToken() => _auth.refreshToken();

  Future<AuthState> getAuthState() => _auth.getAuthState();

  Future<void> signOut() => _auth.signOut();

  Future<String?> cachedUserId() => _tokens.getUserId();

  Future<String?> cachedUserRole() => _tokens.getUserRole();

  Future<List<User>> listUnlockableUsers() {
    return runRepositoryWrite(
      _log,
      'Could not load users',
      'Could not load staff. Try again.',
      () {
        return (_db.select(_db.users)
              ..where((u) => u.deletedAt.isNull())
              ..orderBy([(u) => OrderingTerm.asc(u.name)]))
            .get();
      },
    );
  }

  /// PIN unlock for the selected local user. Operator is the PIN user, not
  /// necessarily the JWT user (API-SPEC.md §2.4 / §8).
  Future<User> unlockWithPin({
    required String userId,
    required String pin,
  }) {
    return runRepositoryWrite(
      _log,
      'PIN unlock failed',
      'Could not unlock. Try again.',
      () async {
        final ok = await _pins.verifyPin(userId, pin);
        if (!ok) {
          throw const RepositoryException('PIN is wrong. Try again.');
        }
        final user = await (_db.select(_db.users)
              ..where((u) => u.id.equals(userId) & u.deletedAt.isNull()))
            .getSingleOrNull();
        if (user == null) {
          throw const RepositoryException('PIN is wrong. Try again.');
        }
        return user;
      },
    );
  }
}

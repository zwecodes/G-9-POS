import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../shared/providers/app_providers.dart';
import '../repositories/auth_repository.dart';

class SessionState {
  const SessionState({
    this.jwtUserId,
    this.jwtUserRole,
    this.operatorId,
    this.operatorRole,
    this.operatorName,
    this.error,
    this.busy = false,
  });

  final String? jwtUserId;
  final String? jwtUserRole;
  final String? operatorId;
  final String? operatorRole;
  final String? operatorName;
  final String? error;
  final bool busy;

  bool get hasJwt => jwtUserId != null && jwtUserId!.isNotEmpty;

  bool get isUnlocked => operatorId != null && operatorId!.isNotEmpty;

  SessionState copyWith({
    String? jwtUserId,
    String? jwtUserRole,
    String? operatorId,
    String? operatorRole,
    String? operatorName,
    String? error,
    bool? busy,
    bool clearOperator = false,
    bool clearError = false,
    bool clearJwt = false,
  }) {
    return SessionState(
      jwtUserId: clearJwt ? null : (jwtUserId ?? this.jwtUserId),
      jwtUserRole: clearJwt ? null : (jwtUserRole ?? this.jwtUserRole),
      operatorId: clearOperator ? null : (operatorId ?? this.operatorId),
      operatorRole: clearOperator ? null : (operatorRole ?? this.operatorRole),
      operatorName: clearOperator ? null : (operatorName ?? this.operatorName),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._repo) : super(const SessionState());

  final AuthRepository _repo;

  Future<void> restore() async {
    final userId = await _repo.cachedUserId();
    final role = await _repo.cachedUserRole();
    state = SessionState(
      jwtUserId: userId,
      jwtUserRole: role,
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.login(username, password);
      final userId = await _repo.cachedUserId();
      final role = await _repo.cachedUserRole();
      state = SessionState(
        jwtUserId: userId,
        jwtUserRole: role,
        operatorId: userId,
        operatorRole: role,
      );
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
    } on RepositoryException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Could not sign in. Check the connection and try again.',
      );
    }
  }

  Future<void> unlockWithPin({
    required String userId,
    required String pin,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _repo.unlockWithPin(userId: userId, pin: pin);
      state = state.copyWith(
        busy: false,
        operatorId: user.id,
        operatorRole: user.role,
        operatorName: user.name,
        clearError: true,
      );
    } on RepositoryException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Could not unlock. Try again.',
      );
    }
  }

  void lock() {
    state = state.copyWith(clearOperator: true, clearError: true);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const SessionState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(authServiceProvider),
    pins: ref.watch(pinServiceProvider),
    tokens: ref.watch(tokenCacheProvider),
    db: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref.watch(authRepositoryProvider));
});

final appIdentityProvider = Provider<AppIdentity>((ref) {
  final session = ref.watch(sessionProvider);
  final devices = ref.watch(deviceIdServiceProvider);
  return AppIdentity(
    deviceId: devices.getOrCreateDeviceId,
    operatorId: () => session.operatorId ?? '',
    operatorRole: () => session.operatorRole ?? '',
  );
});

final unlockableUsersProvider = FutureProvider<List<User>>((ref) {
  return ref.watch(authRepositoryProvider).listUnlockableUsers();
});

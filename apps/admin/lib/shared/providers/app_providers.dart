import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/session_store.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(sessionStoreProvider);
  return ApiClient(
    baseUrl: kApiUrl,
    accessToken: store.accessToken,
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    api: ref.watch(apiClientProvider),
    store: ref.watch(sessionStoreProvider),
  );
});

class SessionState {
  const SessionState({
    this.signedIn = false,
    this.userName,
    this.busy = false,
    this.error,
  });

  final bool signedIn;
  final String? userName;
  final bool busy;
  final String? error;

  SessionState copyWith({
    bool? signedIn,
    String? userName,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      signedIn: signedIn ?? this.signedIn,
      userName: userName ?? this.userName,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._auth, this._store) : super(const SessionState());

  final AuthService _auth;
  final SessionStore _store;

  Future<void> restore() async {
    final has = await _store.hasSession();
    final name = await _store.userName();
    state = SessionState(signedIn: has, userName: name);
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _auth.login(username: username, password: password);
      final name = await _store.userName();
      state = SessionState(signedIn: true, userName: name);
    } on ApiException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Could not sign in. Check the connection and try again.',
      );
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const SessionState();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(
    ref.watch(authServiceProvider),
    ref.watch(sessionStoreProvider),
  );
});

final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(sessionProvider.notifier).restore();
});

import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:g9pos/core/auth/auth_service.dart';
import 'package:g9pos/core/database/app_database.dart';
import 'package:g9pos/core/utils/repository_exception.dart';
import 'package:g9pos/features/auth/providers/auth_providers.dart';

import '../../helpers/test_harness.dart';

void main() {
  setUpAll(silenceLoggers);

  test('PIN unlock succeeds for the selected user and fails on a wrong PIN',
      () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final hash = BCrypt.hashpw('1234', BCrypt.gensalt());
    await repos.db.into(repos.db.users).insert(
          UsersCompanion.insert(
            id: 'staff-1',
            name: 'Aye',
            pin: hash,
            role: 'staff',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    final auth = memoryAuthRepository(db: repos.db);
    final user = await auth.unlockWithPin(userId: 'staff-1', pin: '1234');
    expect(user.id, 'staff-1');
    expect(user.role, 'staff');

    expect(
      () => auth.unlockWithPin(userId: 'staff-1', pin: '0000'),
      throwsA(
        isA<RepositoryException>().having(
          (e) => e.message,
          'message',
          'PIN is wrong. Try again.',
        ),
      ),
    );
  });

  test('owner login caches JWT user and session unlocks as that operator',
      () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final auth = memoryAuthRepository(
      db: repos.db,
      poster: ({
        required uri,
        required body,
        accessToken,
      }) async {
        return AuthHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_at': DateTime.now().millisecondsSinceEpoch + 60 * 1000,
              'user': {'id': 'owner-1', 'role': 'owner'},
            },
            'meta': {},
          }),
        );
      },
    );

    final session = SessionNotifier(auth);
    await session.login('owner', 'secret');
    expect(session.state.error, isNull);
    expect(session.state.jwtUserId, 'owner-1');
    expect(session.state.operatorId, 'owner-1');
    expect(session.state.operatorRole, 'owner');
    expect(session.state.isUnlocked, isTrue);
  });

  test('deleted users cannot unlock', () async {
    final repos = openTestRepos();
    addTearDown(repos.close);

    final hash = BCrypt.hashpw('1234', BCrypt.gensalt());
    await repos.db.into(repos.db.users).insert(
          UsersCompanion.insert(
            id: 'gone',
            name: 'Gone',
            pin: hash,
            role: 'staff',
            createdAt: 1,
            updatedAt: 1,
            deletedAt: const Value(99),
          ),
        );

    final auth = memoryAuthRepository(db: repos.db);
    expect(
      () => auth.unlockWithPin(userId: 'gone', pin: '1234'),
      throwsA(isA<RepositoryException>()),
    );
  });
}

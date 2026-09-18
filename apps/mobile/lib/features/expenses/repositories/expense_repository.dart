import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

/// DATA-MODEL.md §8 — predefined expense categories.
const kExpenseCategories = <String>[
  'Rent',
  'Electricity',
  'Water',
  'Transport',
  'Food',
  'Supplier Payment',
  'Other',
];

class ExpenseDraft {
  const ExpenseDraft({
    required this.category,
    required this.amountMmk,
    this.note,
    this.expenseDate,
  });

  final String category;
  final int amountMmk;
  final String? note;

  /// ISO `YYYY-MM-DD` in shop timezone. Null → today in Asia/Yangon.
  final String? expenseDate;
}

class ExpenseRepository {
  ExpenseRepository({
    required AppDatabase db,
    required AppIdentity identity,
    UuidGenerator? uuids,
    Logger? logger,
    int Function()? nowMs,
  })  : _db = db,
        _identity = identity,
        _uuids = uuids ?? UuidGenerator(),
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs;

  final AppDatabase _db;
  final AppIdentity _identity;
  final UuidGenerator _uuids;
  final Logger _log;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Stream<List<Expense>> watchAll() => _db.expenseDao.watchAllActive();

  Future<List<Expense>> getAll() => _db.expenseDao.getAllActive();

  Future<Expense?> getById(String id) => _db.expenseDao.getById(id);

  /// Owner and staff may create (`API-SPEC.md` §5).
  Future<Expense> create(ExpenseDraft draft) {
    return runRepositoryWrite(
      _log,
      'Could not save expense',
      'Could not save the expense. Try again.',
      () async {
        _validate(draft);
        final id = _uuids.v4();
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        if (operatorId.isEmpty) {
          throw const RepositoryException('Sign in again to save expenses.');
        }
        final expenseDate =
            draft.expenseDate?.trim().isNotEmpty == true
                ? draft.expenseDate!.trim()
                : ShopDateUtils.todayShopDateString();
        final note = _emptyToNull(draft.note);

        await _db.transaction(() async {
          await _db.expenseDao.upsert(
            ExpensesCompanion.insert(
              id: id,
              category: draft.category,
              amountMmk: draft.amountMmk,
              note: Value(note),
              expenseDate: expenseDate,
              operatorId: operatorId,
              deviceId: deviceId,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.expenseCreated,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            referenceId: null,
            extra: {
              'category': draft.category,
              'amount_mmk': draft.amountMmk,
              'note': note,
              'expense_date': expenseDate,
              'operator_id': operatorId,
            },
          );
        });

        return (await _db.expenseDao.getById(id))!;
      },
    );
  }

  /// Soft delete — owner only (`API-SPEC.md` §5).
  Future<void> delete(String id) {
    return runRepositoryWrite(
      _log,
      'Could not delete expense',
      'Could not delete the expense. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final existing = await _db.expenseDao.getById(id);
        if (existing == null) {
          throw const RepositoryException('That expense is no longer available.');
        }
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await _db.transaction(() async {
          await _db.expenseDao.softDelete(id, now);
          await enqueueSyncEvent(
            _db.syncQueueDao,
            id: id,
            eventType: SyncEventType.expenseDeleted,
            deviceId: deviceId,
            operatorId: operatorId,
            createdAt: now,
            referenceId: null,
            extra: {
              'operator_id': operatorId,
            },
          );
        });
      },
    );
  }

  void _validate(ExpenseDraft draft) {
    if (!kExpenseCategories.contains(draft.category)) {
      throw const RepositoryException('Choose an expense category.');
    }
    if (draft.amountMmk <= 0) {
      throw const RepositoryException('Amount must be greater than zero.');
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

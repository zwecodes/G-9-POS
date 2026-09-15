import 'package:drift/native.dart';

import 'app_database.dart';

/// File-backed opener is wired in `main()` (Phase 8). Tests override
/// the database provider with [openMemoryDatabase].
AppDatabase openMemoryDatabase() => AppDatabase(NativeDatabase.memory());

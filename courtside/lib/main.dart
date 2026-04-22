import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_seeder.dart';
import 'features/auth/viewmodels/auth_notifier.dart';

/// Entry point for CourtSide.
///
/// Startup sequence:
///   1. Initialize Flutter's binding so platform channels work.
///   2. Open the SQLite database (via drift).
///   3. Run the seeder to insert the Super Admin + sample Coach
///      accounts on first launch.
///   4. Mount the app, overriding the database provider with the
///      real instance we just opened.
Future<void> main() async {
  // 1. Must be called before any platform-channel work (which
  //    `getApplicationDocumentsDirectory` does under the hood).
  //    Also required because we `await` before `runApp`.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Open the database. This creates `courtside.sqlite` in the app's
  //    documents directory on first launch and runs `CREATE TABLE`
  //    statements for every table defined in AppDatabase.
  final db = AppDatabase();

  // 3. Seed the Super Admin and sample Coach. Idempotent — subsequent
  //    launches see the accounts already exist and skip the inserts.
  await DatabaseSeeder(db).seedIfNeeded();

  // 4. Mount the app. The `overrides` argument replaces the placeholder
  //    `throw UnimplementedError` in appDatabaseProvider with the real
  //    database instance. Every widget that reads the provider gets
  //    this one shared instance.
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const CourtSideApp(),
    ),
  );
}
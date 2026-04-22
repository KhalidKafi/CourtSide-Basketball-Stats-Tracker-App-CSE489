import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// This tells the drift code generator: "emit your generated code into
// a sibling file called app_database.g.dart, and consider it part of
// this library". Do NOT create app_database.g.dart by hand — it's
// generated automatically by `dart run build_runner build`.
part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────
// Tables
//
// Each class below describes one SQL table. Drift reads these at
// build-time and generates:
//   - a row class (e.g. `User`)        — what you get when you read rows
//   - a companion class (`UsersCompanion`) — what you pass to insert/update
//
// Column constraints (PK, UNIQUE, FK) are declared here in Dart and drift
// translates them to the correct SQL DDL when the DB is first created.
// ─────────────────────────────────────────────────────────────────────────

/// USERS — three roles: super_admin, admin, coach
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 3, max: 150).unique()();
  // Stored as "<salt_hex>$<hash_hex>" — see PasswordHasher.
  TextColumn get password => text()();
  // Role values enforced at the application layer (via UserRole.asString).
  // A database-level CHECK would be stricter, but adds migration overhead
  // if we ever need a new role — application-layer enforcement is fine.
  TextColumn get role => text().withLength(min: 4, max: 20)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// TEAMS — owned by a single coach, cascade-deleted if the coach is deleted.
class Teams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get teamName => text().withLength(min: 1, max: 100)();
  TextColumn get season => text().withLength(min: 1, max: 50)();
  TextColumn get homeCourt => text().withLength(min: 1, max: 100)();
  IntColumn get coachId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// PLAYERS — belong to a team. Jersey number is not unique per team at
/// the DB level (to keep inserts simple); the team-roster UI will enforce
/// uniqueness before saving.
class Players extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get jerseyNumber => integer()();
  // PG / SG / SF / PF / C
  TextColumn get position => text().withLength(min: 1, max: 5)();
  IntColumn get teamId =>
      integer().references(Teams, #id, onDelete: KeyAction.cascade)();
}

/// GAMES — one per match. Result is nullable ('win'/'loss'/NULL — no draw).
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get opponent => text().withLength(min: 1, max: 100)();
  // ISO YYYY-MM-DD date string.
  TextColumn get date => text().withLength(min: 10, max: 10)();
  // 'home' | 'away'
  TextColumn get homeAway => text().withLength(min: 4, max: 4)();
  // 'win' | 'loss' | NULL (set at End Game)
  TextColumn get result => text().nullable()();
  // Updated live via the +1/+2/+3 opponent strip, or typed at End Game.
  IntColumn get opponentScore => integer().withDefault(const Constant(0))();
  IntColumn get teamId =>
      integer().references(Teams, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();
}

/// GAME_STATS — raw counts only. FG%, 3P%, FT%, and total points are
/// computed at runtime (see spec Section 11) and NEVER persisted as columns.
/// One row per (game_id, player_id) — enforced by the unique key below.
class GameStats extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gameId =>
      integer().references(Games, #id, onDelete: KeyAction.cascade)();
  IntColumn get playerId =>
      integer().references(Players, #id, onDelete: KeyAction.cascade)();
  IntColumn get twoPtMade => integer().withDefault(const Constant(0))();
  IntColumn get twoPtMissed => integer().withDefault(const Constant(0))();
  IntColumn get threePtMade => integer().withDefault(const Constant(0))();
  IntColumn get threePtMissed => integer().withDefault(const Constant(0))();
  IntColumn get ftMade => integer().withDefault(const Constant(0))();
  IntColumn get ftMissed => integer().withDefault(const Constant(0))();

  // Prevents two stat rows for the same player in the same game.
  @override
  List<Set<Column>> get uniqueKeys => [
        {gameId, playerId},
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// The database class
// ─────────────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Users, Teams, Players, Games, GameStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump this number any time the schema changes AND write a migration
  /// strategy. Phase 1 stays at 1; we'll handle migrations later if needed.
  @override
  int get schemaVersion => 1;

  // ─── USERS queries (Phase 1 uses only these) ────────────────────────────

  Future<User?> findUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();

  Future<User?> findUserById(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<List<User>> allAdmins() =>
      (select(users)..where((u) => u.role.equals('admin'))).get();

  Future<int> deleteUserById(int id) =>
      (delete(users)..where((u) => u.id.equals(id))).go();

  Future<int> updateUserPassword(int id, String newHashedPassword) =>
      (update(users)..where((u) => u.id.equals(id)))
          .write(UsersCompanion(password: Value(newHashedPassword)));
}

// ─────────────────────────────────────────────────────────────────────────
// Connection setup
// ─────────────────────────────────────────────────────────────────────────

/// Opens the SQLite database file inside the app's documents directory.
///
/// `LazyDatabase` defers opening until the first query is made. This
/// matters because `getApplicationDocumentsDirectory()` is async and
/// can't run in the `AppDatabase()` constructor, which is sync.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'courtside.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
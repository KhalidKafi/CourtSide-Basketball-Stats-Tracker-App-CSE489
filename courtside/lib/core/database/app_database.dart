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
  BoolColumn get isDisabled => boolean().withDefault(const Constant(false))();
}

/// TEAMS — owned by a single coach, cascade-deleted if the coach is deleted.
@DataClassName('TeamRow')
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
@DataClassName('PlayerRow')
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
@DataClassName('GameRow')
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// GAME_STATS — raw counts only. FG%, 3P%, FT%, and total points are
/// computed at runtime (see spec Section 11) and NEVER persisted as columns.
/// One row per (game_id, player_id) — enforced by the unique key below.
@DataClassName('GameStatRow')
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

/// FLAGS — Admin raises a flag on a team or game for Super Admin review.
/// target_type tells us which table target_id points at; we don't use a
/// strict FK because target_id could point at different tables depending
/// on target_type. We clean up orphans manually when the target is deleted.
class Flags extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'team' | 'game'
  TextColumn get targetType => text().withLength(min: 4, max: 5)();
  IntColumn get targetId => integer()();
  TextColumn get reason => text().withLength(min: 1, max: 500)();
  IntColumn get flaggedByAdminId =>
      integer().references(Users, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get flaggedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  IntColumn get resolvedBySuperAdminId =>
      integer().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────
// The database class
// ─────────────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Users, Teams, Players, Games, GameStats, Flags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  /// Drift runs this when the stored schema version doesn't match the
  /// current code. On fresh installs, `onCreate` runs; on upgrades,
  /// `onUpgrade` runs for each step from the stored version to the current.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Fresh install — create everything from scratch.
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: add is_disabled to users, add flags table.
            await m.addColumn(users, users.isDisabled as GeneratedColumn<Object>);
            await m.createTable(flags);
          }
        },
      );

  // ─── USERS queries (Phase 1 uses only these) ────────────────────────────

  Future<User?> findUserByEmail(String email) =>
      (select(users)..where((u) => u.email.equals(email))).getSingleOrNull();

  /// Like findUserByEmail but only returns non-disabled users. Used by
  /// login — disabled accounts should fail authentication as if they
  /// didn't exist (we don't leak "this account is disabled" vs "no such
  /// account" because the existence of a disabled account is sensitive).
  Future<User?> findActiveUserByEmail(String email) => (select(users)
        ..where((u) => u.email.equals(email) & u.isDisabled.equals(false)))
      .getSingleOrNull();

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

  // ─── TEAMS queries ──────────────────────────────────────────────────

  /// Streaming query — emits the current list of teams for a coach, and
  /// emits a NEW list every time the teams table changes (insert, update,
  /// delete). Subscribers (via Riverpod StreamProvider) rebuild automatically.
  Stream<List<TeamRow>> watchTeamsForCoach(int coachId) {
    return (select(teams)
          ..where((t) => t.coachId.equals(coachId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<TeamRow?> findTeamById(int id) =>
      (select(teams)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTeam(TeamsCompanion team) => into(teams).insert(team);

  Future<int> updateTeam(int id, TeamsCompanion changes) =>
      (update(teams)..where((t) => t.id.equals(id))).write(changes);

  Future<int> deleteTeamById(int id) =>
      (delete(teams)..where((t) => t.id.equals(id))).go();

  /// Counts games played by a team — used to show "games count" badges
  /// on the team list.
  Future<int> countGamesForTeam(int teamId) async {
    final countExp = games.id.count();
    final query = selectOnly(games)
      ..addColumns([countExp])
      ..where(games.teamId.equals(teamId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Counts total players across ALL teams owned by a coach.
  /// Single query via JOIN. Streams so the dashboard auto-updates.
  Stream<int> watchTotalPlayersForCoach(int coachId) {
    final countExp = players.id.count();
    final query = selectOnly(players).join([
      innerJoin(teams, teams.id.equalsExp(players.teamId)),
    ])
      ..addColumns([countExp])
      ..where(teams.coachId.equals(coachId));
    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  // ─── PLAYERS queries ────────────────────────────────────────────────

  /// Streaming list of players for a team, ordered by jersey number ascending.
  Stream<List<PlayerRow>> watchPlayersForTeam(int teamId) {
    return (select(players)
          ..where((p) => p.teamId.equals(teamId))
          ..orderBy([(p) => OrderingTerm.asc(p.jerseyNumber)]))
        .watch();
  }

  Future<List<PlayerRow>> getPlayersForTeam(int teamId) =>
      (select(players)
            ..where((p) => p.teamId.equals(teamId))
            ..orderBy([(p) => OrderingTerm.asc(p.jerseyNumber)]))
          .get();

  Future<PlayerRow?> findPlayerById(int id) =>
      (select(players)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertPlayer(PlayersCompanion player) =>
      into(players).insert(player);

  Future<int> updatePlayer(int id, PlayersCompanion changes) =>
      (update(players)..where((p) => p.id.equals(id))).write(changes);

  Future<int> deletePlayerById(int id) =>
      (delete(players)..where((p) => p.id.equals(id))).go();

  /// Checks whether a jersey number is already taken on a team. Used
  /// during add/edit to validate uniqueness at the team-roster level.
  /// Pass `excludePlayerId` when editing to allow a player to keep their
  /// current number.
  Future<bool> isJerseyTaken({
    required int teamId,
    required int jerseyNumber,
    int? excludePlayerId,
  }) async {
    final query = select(players)
      ..where((p) =>
          p.teamId.equals(teamId) & p.jerseyNumber.equals(jerseyNumber));
    final results = await query.get();
    if (excludePlayerId != null) {
      return results.any((p) => p.id != excludePlayerId);
    }
    return results.isNotEmpty;
  }

  // ─── GAMES queries ──────────────────────────────────────────────────

  /// Streaming list of games for a team, most recent first.
  Stream<List<GameRow>> watchGamesForTeam(int teamId) {
    return (select(games)
          ..where((g) => g.teamId.equals(teamId))
          ..orderBy([
            (g) => OrderingTerm.desc(g.date),
            (g) => OrderingTerm.desc(g.createdAt),
          ]))
        .watch();
  }

  /// Streams the most recent games + their team names across ALL teams
  /// owned by a coach. Returns a list of (GameRow, teamName) tuples.
  Stream<List<({GameRow game, String teamName})>>
      watchRecentGamesWithTeamNameForCoach({
    required int coachId,
    int limit = 5,
  }) {
    final query = select(games).join([
      innerJoin(teams, teams.id.equalsExp(games.teamId)),
    ])
      ..where(teams.coachId.equals(coachId))
      ..orderBy([
        OrderingTerm.desc(games.date),
        OrderingTerm.desc(games.createdAt),
      ])
      ..limit(limit);

    return query.watch().map(
          (rows) => rows
              .map((r) => (
                    game: r.readTable(games),
                    teamName: r.readTable(teams).teamName,
                  ))
              .toList(),
        );
  }

  /// One-shot game lookup.
  Future<GameRow?> findGameById(int id) =>
      (select(games)..where((g) => g.id.equals(id))).getSingleOrNull();

  /// Streaming version of findGameById. Emits the row whenever it changes,
  /// or null if it doesn't exist (yet or anymore).
  Stream<GameRow?> watchGameById(int id) {
    return (select(games)..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insertGame(GamesCompanion game) => into(games).insert(game);

  Future<int> updateGame(int id, GamesCompanion changes) =>
      (update(games)..where((g) => g.id.equals(id))).write(changes);

  Future<int> deleteGameById(int id) =>
      (delete(games)..where((g) => g.id.equals(id))).go();

  /// Streams the in-progress game for a team if any. There can be at most
  /// one — the new game flow refuses to start a second if one is already
  /// in progress. Returns null if none exists.
  Stream<GameRow?> watchInProgressGameForTeam(int teamId) {
    return (select(games)
          ..where((g) =>
              g.teamId.equals(teamId) & g.isFinished.equals(false))
          ..limit(1))
        .watchSingleOrNull();
  }

  // ─── GAME_STATS queries ─────────────────────────────────────────────

  /// Streaming map of player_id → GameStatRow for one game. Used by the
  /// live game screen to keep per-player stats in sync as actions are
  /// logged. Returned as a list; the notifier turns it into a map.
  Stream<List<GameStatRow>> watchStatsForGame(int gameId) {
    return (select(gameStats)..where((s) => s.gameId.equals(gameId))).watch();
  }

  Future<List<GameStatRow>> getStatsForGame(int gameId) =>
      (select(gameStats)..where((s) => s.gameId.equals(gameId))).get();

  /// Inserts a zero-stat row for every player in the team. Called once
  /// when a game is created so every player has a row to update during
  /// the live session — no "row not found" branch needed in the hot path.
  Future<void> initializeStatsForGame({
    required int gameId,
    required List<int> playerIds,
  }) async {
    await batch((b) {
      b.insertAll(
        gameStats,
        [
          for (final playerId in playerIds)
            GameStatsCompanion.insert(gameId: gameId, playerId: playerId),
        ],
      );
    });
  }

  /// Updates a single stat row. Used by the live action handler.
  Future<int> updateGameStat(int statId, GameStatsCompanion changes) =>
      (update(gameStats)..where((s) => s.id.equals(statId))).write(changes);

  /// Finds a stat row by (gameId, playerId). The unique key on these
  /// two columns guarantees at most one match.
  Future<GameStatRow?> findStatRow({
    required int gameId,
    required int playerId,
  }) =>
      (select(gameStats)
            ..where(
                (s) => s.gameId.equals(gameId) & s.playerId.equals(playerId)))
          .getSingleOrNull();

  // ─── Analytics queries ────────

  /// Streams ALL stat rows for ALL games of a team, joined so we can
  /// see which game each row belongs to. Used for season analytics —
  /// the screen aggregates these in Dart for flexibility.
  Stream<List<({GameStatRow stat, GameRow game})>>
      watchSeasonStatsForTeam(int teamId) {
    final query = select(gameStats).join([
      innerJoin(games, games.id.equalsExp(gameStats.gameId)),
    ])
      ..where(games.teamId.equals(teamId) & games.isFinished.equals(true))
      ..orderBy([OrderingTerm.asc(games.date)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => (
                    stat: r.readTable(gameStats),
                    game: r.readTable(games),
                  ))
              .toList(),
        );
  }

  /// Streams all stat rows for one player across all their team's finished
  /// games. Used by the player profile screen.
  Stream<List<({GameStatRow stat, GameRow game})>>
      watchSeasonStatsForPlayer(int playerId) {
    final query = select(gameStats).join([
      innerJoin(games, games.id.equalsExp(gameStats.gameId)),
    ])
      ..where(gameStats.playerId.equals(playerId) &
          games.isFinished.equals(true))
      ..orderBy([OrderingTerm.asc(games.date)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => (
                    stat: r.readTable(gameStats),
                    game: r.readTable(games),
                  ))
              .toList(),
        );
  }

  // ─── Admin / Super Admin queries ────────────────────────────────────

  Stream<List<User>> watchAllCoaches() {
    return (select(users)
          ..where((u) => u.role.equals('coach'))
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  Stream<List<User>> watchAllAdmins() {
    return (select(users)
          ..where((u) => u.role.equals('admin'))
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]))
        .watch();
  }

  Future<int> setUserDisabled(int userId, bool disabled) {
    return (update(users)..where((u) => u.id.equals(userId)))
        .write(UsersCompanion(isDisabled: Value(disabled)));
  }

  Stream<({int coaches, int teams, int players, int games})>
      watchSystemCounts() async* {
    yield await _readSystemCounts();
    await for (final _ in tableUpdates(
        TableUpdateQuery.onAllTables([users, teams, players, games]))) {
      yield await _readSystemCounts();
    }
  }

  Future<({int coaches, int teams, int players, int games})>
      _readSystemCounts() async {
    final c = await _countCoaches();
    final t = await _countAll(teams);
    final p = await _countAll(players);
    final g = await _countAll(games);
    return (coaches: c, teams: t, players: p, games: g);
  }

  Future<int> _countCoaches() async {
    final exp = users.id.count();
    final row = await (selectOnly(users)
          ..addColumns([exp])
          ..where(users.role.equals('coach')))
        .getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> _countAll<T extends HasResultSet, R>(
      ResultSetImplementation<T, R> table) async {
    final exp = countAll();
    final row = await (selectOnly(table)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0;
  }

  // ─── Flags queries ──────────────────────────────────────────────────

  Stream<List<Flag>> watchUnresolvedFlags() {
    return (select(flags)
          ..where((f) => f.resolved.equals(false))
          ..orderBy([(f) => OrderingTerm.desc(f.flaggedAt)]))
        .watch();
  }

  Future<int> insertFlag(FlagsCompanion flag) => into(flags).insert(flag);

  Future<int> resolveFlag({
    required int flagId,
    required int superAdminId,
  }) {
    return (update(flags)..where((f) => f.id.equals(flagId))).write(
      FlagsCompanion(
        resolved: const Value(true),
        resolvedBySuperAdminId: Value(superAdminId),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteFlagsForTarget({
    required String targetType,
    required int targetId,
  }) {
    return (delete(flags)
          ..where((f) =>
              f.targetType.equals(targetType) & f.targetId.equals(targetId)))
        .go();
  }
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
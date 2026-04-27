import 'package:drift/drift.dart' show Value;

import '../core/database/app_database.dart';
import '../models/game.dart';

class GameRepository {
  GameRepository(this._db);

  final AppDatabase _db;

  // ─── Streaming reads ────────────────────────────────────────────────────

  Stream<List<Game>> watchGamesForTeam(int teamId) {
    return _db
        .watchGamesForTeam(teamId)
        .map((rows) => rows.map(_toGame).toList());
  }

  Stream<Game?> watchInProgressGameForTeam(int teamId) {
    return _db
        .watchInProgressGameForTeam(teamId)
        .map((row) => row == null ? null : _toGame(row));
  }

  // ─── One-shot reads ─────────────────────────────────────────────────────

  Future<Game?> findById(int id) async {
    final row = await _db.findGameById(id);
    return row == null ? null : _toGame(row);
  }

  Stream<Game?> watchGameById(int id) {
    return _db.watchGameById(id).map((row) => row == null ? null : _toGame(row));
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  /// Creates a new game and pre-initializes a stat row for every player
  /// on the team. Returns the new game's ID.
  ///
  /// Done as a single transaction so we never have a half-created game
  /// (game row inserted but stats missing).
  Future<int> createGame({
    required int teamId,
    required String opponent,
    required DateTime date,
    required HomeAway homeAway,
    required List<int> playerIds,
  }) async {
    return await _db.transaction(() async {
      final newGameId = await _db.insertGame(GamesCompanion.insert(
        opponent: opponent.trim(),
        date: _formatDate(date),
        homeAway: homeAway.code,
        teamId: teamId,
      ));
      await _db.initializeStatsForGame(
        gameId: newGameId,
        playerIds: playerIds,
      );
      return newGameId;
    });
  }

  /// Live update — increments the opponent score by `delta` (typically
  /// 1, 2, or 3 from the +1/+2/+3 strip).
  Future<void> bumpOpponentScore({
    required int gameId,
    required int delta,
  }) async {
    final game = await _db.findGameById(gameId);
    if (game == null) return;
    await _db.updateGame(
      gameId,
      GamesCompanion(opponentScore: Value(game.opponentScore + delta)),
    );
  }

  /// Sets the opponent score to a specific value (used in End Game dialog
  /// when the coach types the final score directly).
  Future<void> setOpponentScore({
    required int gameId,
    required int score,
  }) async {
    await _db.updateGame(
      gameId,
      GamesCompanion(opponentScore: Value(score)),
    );
  }

  /// Finalizes a game with a result and (optionally) updated opponent score.
  Future<void> endGame({
    required int gameId,
    required GameResult result,
    int? opponentScore,
  }) async {
    await _db.updateGame(
      gameId,
      GamesCompanion(
        isFinished: const Value(true),
        result: Value(result.code),
        opponentScore: opponentScore != null
            ? Value(opponentScore)
            : const Value.absent(),
      ),
    );
  }

  Future<void> deleteGame(int id) => _db.deleteGameById(id).then((_) {});

  // ─── Mapping helpers ────────────────────────────────────────────────────

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime _parseDate(String s) {
    return DateTime.parse(s); // accepts YYYY-MM-DD
  }

  static Game _toGame(GameRow row) {
    return Game(
      id: row.id,
      opponent: row.opponent,
      date: _parseDate(row.date),
      homeAway: HomeAwayX.fromCode(row.homeAway),
      result: row.result == null ? null : GameResultX.fromCode(row.result!),
      opponentScore: row.opponentScore,
      teamId: row.teamId,
      isFinished: row.isFinished,
      createdAt: row.createdAt,
    );
  }
}
import 'package:drift/drift.dart' show Value;

import '../core/database/app_database.dart';
import '../models/player.dart';

class PlayerRepository {
  PlayerRepository(this._db);

  final AppDatabase _db;

  // ─── Streaming reads ────────────────────────────────────────────────────

  /// Auto-updating list of players for a team, ordered by jersey number.
  Stream<List<Player>> watchPlayersForTeam(int teamId) {
    return _db
        .watchPlayersForTeam(teamId)
        .map((rows) => rows.map(_toPlayer).toList());
  }

  // ─── One-shot reads ─────────────────────────────────────────────────────

  Future<List<Player>> getPlayersForTeam(int teamId) async {
    final rows = await _db.getPlayersForTeam(teamId);
    return rows.map(_toPlayer).toList();
  }

  Future<Player?> findById(int id) async {
    final row = await _db.findPlayerById(id);
    return row == null ? null : _toPlayer(row);
  }

  Future<bool> isJerseyTaken({
    required int teamId,
    required int jerseyNumber,
    int? excludePlayerId,
  }) {
    return _db.isJerseyTaken(
      teamId: teamId,
      jerseyNumber: jerseyNumber,
      excludePlayerId: excludePlayerId,
    );
  }

  // ─── Mutations ──────────────────────────────────────────────────────────

  /// Result type for player create/edit — lets the ViewModel
  /// surface "jersey taken" without throwing.
  Future<PlayerWriteResult> createPlayer({
    required int teamId,
    required String name,
    required int jerseyNumber,
    required PlayerPosition position,
  }) async {
    if (await isJerseyTaken(teamId: teamId, jerseyNumber: jerseyNumber)) {
      return const PlayerWriteResult.failure(
        'Jersey number is already taken on this team.',
      );
    }
    final newId = await _db.insertPlayer(PlayersCompanion.insert(
      name: name.trim(),
      jerseyNumber: jerseyNumber,
      position: position.code,
      teamId: teamId,
    ));
    return PlayerWriteResult.success(newId);
  }

  Future<PlayerWriteResult> updatePlayer({
    required int id,
    required int teamId,
    String? name,
    int? jerseyNumber,
    PlayerPosition? position,
  }) async {
    if (jerseyNumber != null) {
      final taken = await isJerseyTaken(
        teamId: teamId,
        jerseyNumber: jerseyNumber,
        excludePlayerId: id,
      );
      if (taken) {
        return const PlayerWriteResult.failure(
          'Jersey number is already taken on this team.',
        );
      }
    }
    await _db.updatePlayer(
      id,
      PlayersCompanion(
        name: name != null ? Value(name.trim()) : const Value.absent(),
        jerseyNumber:
            jerseyNumber != null ? Value(jerseyNumber) : const Value.absent(),
        position:
            position != null ? Value(position.code) : const Value.absent(),
      ),
    );
    return PlayerWriteResult.success(id);
  }

  Future<void> deletePlayer(int id) =>
      _db.deletePlayerById(id).then((_) {});

  // ─── Mapping ────────────────────────────────────────────────────────────

  static Player _toPlayer(PlayerRow row) {
    return Player(
      id: row.id,
      name: row.name,
      jerseyNumber: row.jerseyNumber,
      position: PlayerPositionX.fromCode(row.position),
      teamId: row.teamId,
    );
  }
}

/// Result of a player write operation.
class PlayerWriteResult {
  final int? playerId;
  final String? error;

  const PlayerWriteResult.success(int this.playerId) : error = null;
  const PlayerWriteResult.failure(String this.error) : playerId = null;

  bool get isSuccess => playerId != null;
}
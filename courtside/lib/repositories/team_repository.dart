import 'package:drift/drift.dart' show Value;

import '../core/database/app_database.dart';
import '../models/team.dart';

class TeamRepository {
  TeamRepository(this._db);

  final AppDatabase _db;

  // ─── Streaming reads ────────────────────────────────────────────────────

  /// Auto-updating list of teams owned by a coach. Subscribing widgets
  /// rebuild whenever any team changes.
  Stream<List<Team>> watchTeamsForCoach(int coachId) {
    return _db
        .watchTeamsForCoach(coachId)
        .map((rows) => rows.map(_toTeam).toList());
  }

  // ─── One-shot reads ─────────────────────────────────────────────────────

  Future<Team?> findById(int id) async {
    final row = await _db.findTeamById(id);
    return row == null ? null : _toTeam(row);
  }

  Future<int> countGames(int teamId) => _db.countGamesForTeam(teamId);

  // ─── Mutations ──────────────────────────────────────────────────────────

  /// Creates a new team owned by [coachId]. Returns the new team's ID.
  Future<int> createTeam({
    required int coachId,
    required String name,
    required String season,
    required String homeCourt,
  }) {
    return _db.insertTeam(TeamsCompanion.insert(
      teamName: name.trim(),
      season: season.trim(),
      homeCourt: homeCourt.trim(),
      coachId: coachId,
    ));
  }

  /// Updates an existing team. Only the fields you pass as non-null
  /// are changed — the rest are left untouched.
  Future<void> updateTeam({
    required int id,
    String? name,
    String? season,
    String? homeCourt,
  }) async {
    await _db.updateTeam(
      id,
      TeamsCompanion(
        teamName: name != null ? Value(name.trim()) : const Value.absent(),
        season: season != null ? Value(season.trim()) : const Value.absent(),
        homeCourt:
            homeCourt != null ? Value(homeCourt.trim()) : const Value.absent(),
      ),
    );
  }

  /// Deletes a team. Foreign keys cascade — all its players, games,
  /// and game_stats are deleted too.
  Future<void> deleteTeam(int id) => _db.deleteTeamById(id).then((_) {});

  // ─── Mapping ────────────────────────────────────────────────────────────

  static Team _toTeam(TeamRow row) {
    return Team(
      id: row.id,
      name: row.teamName,
      season: row.season,
      homeCourt: row.homeCourt,
      coachId: row.coachId,
      createdAt: row.createdAt,
    );
  }
}
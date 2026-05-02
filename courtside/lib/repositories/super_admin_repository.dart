import '../core/database/app_database.dart';
import '../core/utils/user_role.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// Plain-Dart representation of an unresolved flag, with the admin's
/// name pre-joined for display.
class FlagItem {
  final int id;
  final String targetType; // 'team' | 'game'
  final int targetId;
  final String reason;
  final String flaggedByName;
  final DateTime flaggedAt;

  const FlagItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.flaggedByName,
    required this.flaggedAt,
  });
}

class SuperAdminRepository {
  SuperAdminRepository(this._db, this._authRepo);
  final AppDatabase _db;
  final AuthRepository _authRepo;

  // ─── Admin management ──────────────────────────────────────────────────

  Stream<List<AppUser>> watchAllAdmins() {
    return _db.watchAllAdmins().map(
          (rows) => rows.map(_toAppUser).toList(),
        );
  }

  /// Delegates to the AuthRepository so account creation goes through
  /// the same hashing / validation path.
  Future<AuthResult> createAdmin({
    required String name,
    required String email,
    required String password,
  }) {
    return _authRepo.createAdmin(name: name, email: email, password: password);
  }

  Future<void> resetAdminPassword(int adminId, String newPassword) {
    return _authRepo.resetAdminPassword(adminId, newPassword);
  }

  Future<void> deleteAdmin(int adminId) {
    return _authRepo.deleteAdmin(adminId);
  }

  // ─── Cascade deletes (the nuclear options) ──────────────────────────────

  /// Delete a coach. FK cascades automatically delete their teams,
  /// players, games, and game_stats.
  Future<void> deleteCoach(int coachId) async {
    await _db.deleteUserById(coachId);
  }

  /// Surgical delete of a single team (cascades to its players, games, stats).
  Future<void> deleteTeam(int teamId) async {
    await _db.deleteTeamById(teamId);
    // Clear any flags that referenced this target.
    await _db.deleteFlagsForTarget(targetType: 'team', targetId: teamId);
  }

  Future<void> deleteGame(int gameId) async {
    await _db.deleteGameById(gameId);
    await _db.deleteFlagsForTarget(targetType: 'game', targetId: gameId);
  }

  // ─── Flag queue ────────────────────────────────────────────────────────

  Stream<List<FlagItem>> watchUnresolvedFlags() async* {
    await for (final rows in _db.watchUnresolvedFlags()) {
      // Hydrate each row with the admin name. We do this in Dart since
      // the count is small (typically <20 unresolved).
      final items = <FlagItem>[];
      for (final r in rows) {
        final admin = await _db.findUserById(r.flaggedByAdminId);
        items.add(FlagItem(
          id: r.id,
          targetType: r.targetType,
          targetId: r.targetId,
          reason: r.reason,
          flaggedByName: admin?.name ?? 'Unknown admin',
          flaggedAt: r.flaggedAt,
        ));
      }
      yield items;
    }
  }

  Future<void> dismissFlag({
    required int flagId,
    required int superAdminId,
  }) async {
    await _db.resolveFlag(flagId: flagId, superAdminId: superAdminId);
  }

  /// Deletes the flag's target AND marks the flag resolved.
  Future<void> deleteFlagTarget({
    required FlagItem flag,
    required int superAdminId,
  }) async {
    if (flag.targetType == 'team') {
      await deleteTeam(flag.targetId);
    } else if (flag.targetType == 'game') {
      await deleteGame(flag.targetId);
    }
    // The cascade in deleteTeam/deleteGame already removed flags for
    // that target, so no need to mark this one resolved separately.
  }

  // ─── Mapping ────────────────────────────────────────────────────────────

  static AppUser _toAppUser(User row) {
    return AppUser(
      id: row.id,
      name: row.name,
      email: row.email,
      role: UserRoleX.fromString(row.role),
      createdAt: row.createdAt,
    );
  }
}
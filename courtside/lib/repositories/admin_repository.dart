import '../core/database/app_database.dart';
import '../core/utils/user_role.dart';
import '../models/app_user.dart';

/// Operations available to Admins (read-only oversight + flag + disable).
class AdminRepository {
  AdminRepository(this._db);
  final AppDatabase _db;

  // ─── System-wide reads ──────────────────────────────────────────────────

  Stream<List<AppUser>> watchAllCoaches() {
    return _db.watchAllCoaches().map(
          (rows) => rows.map(_toAppUser).toList(),
        );
  }

  Stream<SystemCounts> watchSystemCounts() {
    return _db.watchSystemCounts();
  }

  Future<AppUser?> findCoachById(int id) async {
    final row = await _db.findUserById(id);
    if (row == null) return null;
    return _toAppUser(row);
  }

  // ─── Disable / enable a coach ───────────────────────────────────────────

  Future<void> setCoachDisabled(int coachId, bool disabled) async {
    await _db.setUserDisabled(coachId, disabled);
  }

  // ─── Raise a flag on a team or game ─────────────────────────────────────

  Future<void> flagTeam({
    required int teamId,
    required int adminId,
    required String reason,
  }) async {
    await _db.insertFlag(FlagsCompanion.insert(
      targetType: 'team',
      targetId: teamId,
      reason: reason.trim(),
      flaggedByAdminId: adminId,
    ));
  }

  Future<void> flagGame({
    required int gameId,
    required int adminId,
    required String reason,
  }) async {
    await _db.insertFlag(FlagsCompanion.insert(
      targetType: 'game',
      targetId: gameId,
      reason: reason.trim(),
      flaggedByAdminId: adminId,
    ));
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


import '../utils/password_hasher.dart';
import '../utils/user_role.dart';
import 'app_database.dart';

/// Seeds the database with initial data on first launch.
///
/// Idempotent: safe to run on every app start. Each seed operation first
/// checks whether the target row already exists (by unique email) and
/// skips the insert if it does. This avoids needing a "has_seeded" flag
/// in shared_preferences — which could get out of sync if the user wipes
/// app data but shared_preferences persists.
///
/// Phase 1 seeds the Super Admin and a sample Coach account.
/// Later phases will extend this with a sample team + 8 players + 3
/// completed games so the charts and leaderboards have meaningful
/// data for the viva demo.
class DatabaseSeeder {
  DatabaseSeeder(this._db);

  final AppDatabase _db;

  // ─── Hardcoded credentials — documented in the project README ──────────

  static const String superAdminEmail = 'superadmin@courtside.app';
  static const String superAdminPassword = 'SuperAdmin@2026';
  static const String superAdminName = 'Super Admin';

  static const String sampleCoachEmail = 'coach@courtside.app';
  static const String sampleCoachPassword = 'Coach@2026';
  static const String sampleCoachName = 'John Smith';

  // ─── Public entry point ────────────────────────────────────────────────

  Future<void> seedIfNeeded() async {
    await _seedSuperAdmin();
    await _seedSampleCoach();
    // Later phases will call: await _seedSampleTeamAndPlayers();
    //                         await _seedSampleGames();
  }

  // ─── Private seed operations ───────────────────────────────────────────

  Future<void> _seedSuperAdmin() async {
    final existing = await _db.findUserByEmail(superAdminEmail);
    if (existing != null) return;

    await _db.insertUser(UsersCompanion.insert(
      name: superAdminName,
      email: superAdminEmail,
      password: PasswordHasher.hash(superAdminPassword),
      role: UserRole.superAdmin.asString,
    ));
  }

  Future<void> _seedSampleCoach() async {
    final existing = await _db.findUserByEmail(sampleCoachEmail);
    if (existing != null) return;

    await _db.insertUser(UsersCompanion.insert(
      name: sampleCoachName,
      email: sampleCoachEmail,
      password: PasswordHasher.hash(sampleCoachPassword),
      role: UserRole.coach.asString,
    ));
  }
}
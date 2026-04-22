import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/utils/password_hasher.dart';
import '../core/utils/user_role.dart';
import '../models/app_user.dart';

/// Result of an auth operation.
///
/// Using a result type instead of throwing exceptions lets the ViewModel
/// pattern-match on success/failure without try/catch plumbing, and lets
/// us carry a human-readable error message all the way up to a SnackBar
/// without inventing a custom Exception class.
class AuthResult {
  final AppUser? user;
  final String? error;

  const AuthResult.success(AppUser this.user) : error = null;
  const AuthResult.failure(String this.error) : user = null;

  bool get isSuccess => user != null;
}

/// Handles all authentication operations: register, login, session
/// persistence, and super-admin account management.
///
/// Stateless — the same instance can be shared across the app and called
/// from anywhere safely. Session state lives in `shared_preferences`,
/// not in this class.
class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  /// Key under which we persist the currently logged-in user's ID.
  /// On app restart, the session loader reads this and rehydrates the user.
  static const String _kSessionUserIdKey = 'session_user_id';

  // ─── Register (Coach role only, via the public form) ────────────────────

  /// Registers a new Coach. Enforces unique email and hashes the password.
  ///
  /// This path ONLY creates coaches. Admin and Super Admin accounts are
  /// created via separate flows (seeder for Super Admin; `createAdmin`
  /// below for Admin).
  Future<AuthResult> registerCoach({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();

    final existing = await _db.findUserByEmail(normalized);
    if (existing != null) {
      return const AuthResult.failure(
        'An account with this email already exists.',
      );
    }

    final hashed = PasswordHasher.hash(password);

    final newId = await _db.insertUser(UsersCompanion.insert(
      name: name.trim(),
      email: normalized,
      password: hashed,
      role: UserRole.coach.asString,
    ));

    final row = await _db.findUserById(newId);
    if (row == null) {
      // The row we just inserted is missing. This should never happen;
      // it would mean the DB dropped the row between insert and select,
      // or our SELECT is pointed at a different table. Fail loudly.
      return const AuthResult.failure('Account creation failed unexpectedly.');
    }
    return AuthResult.success(_toAppUser(row));
  }

  // ─── Create Admin (Super Admin action — Phase 2) ────────────────────────

  /// Creates an Admin account. The caller must enforce that only a Super
  /// Admin invokes this — router guards and UI gating will handle that.
  /// The repository itself does not authorize, because checks here would
  /// be bypassable from the ViewModel layer anyway.
  Future<AuthResult> createAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();

    final existing = await _db.findUserByEmail(normalized);
    if (existing != null) {
      return const AuthResult.failure(
        'An account with this email already exists.',
      );
    }

    final hashed = PasswordHasher.hash(password);

    final newId = await _db.insertUser(UsersCompanion.insert(
      name: name.trim(),
      email: normalized,
      password: hashed,
      role: UserRole.admin.asString,
    ));

    final row = await _db.findUserById(newId);
    if (row == null) {
      return const AuthResult.failure('Admin creation failed unexpectedly.');
    }
    return AuthResult.success(_toAppUser(row));
  }

  // ─── Login ──────────────────────────────────────────────────────────────

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final row = await _db.findUserByEmail(normalized);

    if (row == null) {
      return const AuthResult.failure('No account found with this email.');
    }
    if (!PasswordHasher.verify(password, row.password)) {
      return const AuthResult.failure('Incorrect password.');
    }

    await _persistSession(row.id);
    return AuthResult.success(_toAppUser(row));
  }

  // ─── Session persistence ────────────────────────────────────────────────

  /// Called on app startup by the SplashScreen to restore a saved session.
  /// Returns null if no session or if the saved user has been deleted.
  Future<AppUser?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kSessionUserIdKey);
    if (id == null) return null;

    final row = await _db.findUserById(id);
    if (row == null) {
      // Stale session — the saved user was deleted (e.g. Super Admin
      // deleted this admin while they were logged in). Clear the stale
      // key so we don't keep trying to restore a missing user.
      await prefs.remove(_kSessionUserIdKey);
      return null;
    }
    return _toAppUser(row);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionUserIdKey);
  }

  Future<void> _persistSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSessionUserIdKey, userId);
  }

  // ─── Admin management (Super Admin — Phase 2) ──────────────────────────

  Future<List<AppUser>> listAllAdmins() async {
    final rows = await _db.allAdmins();
    return rows.map(_toAppUser).toList();
  }

  Future<void> deleteAdmin(int adminId) async {
    await _db.deleteUserById(adminId);
  }

  /// Reset an admin's password. Takes a plaintext password, hashes it,
  /// writes the hash. The plaintext is never stored.
  Future<void> resetAdminPassword(int adminId, String newPassword) async {
    final hashed = PasswordHasher.hash(newPassword);
    await _db.updateUserPassword(adminId, hashed);
  }

  // ─── Mapping ───────────────────────────────────────────────────────────

  /// Translates a drift `User` row into our domain `AppUser`.
  /// Notice that `row.password` is deliberately not copied across — the
  /// password hash stops at the repository boundary. No other layer
  /// should ever see it.
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
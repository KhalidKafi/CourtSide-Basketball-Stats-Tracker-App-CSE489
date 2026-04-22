/// The three user roles in CourtSide.
///
/// Stored in the USERS.role column as a lowercase string. Use [asString]
/// when writing to the DB and [UserRoleX.fromString] when reading back.
enum UserRole {
  superAdmin,
  admin,
  coach,
}

extension UserRoleX on UserRole {
  /// The canonical string form stored in the database.
  String get asString {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.coach:
        return 'coach';
    }
  }

  /// Human-readable name for UI labels.
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.coach:
        return 'Coach';
    }
  }

  /// Parse a role string read from the database back into a [UserRole].
  /// Throws [ArgumentError] on an unknown value — this should only happen
  /// if the DB has been manually corrupted, so failing loudly is correct.
  static UserRole fromString(String raw) {
    switch (raw) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'coach':
        return UserRole.coach;
      default:
        throw ArgumentError('Unknown role string: $raw');
    }
  }
}
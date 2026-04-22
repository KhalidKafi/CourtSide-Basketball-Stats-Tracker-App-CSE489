import '../core/utils/user_role.dart';

/// A plain-Dart representation of a user, decoupled from the drift-generated
/// row class. This is what ViewModels and UI code work with — never the
/// drift `User` row class directly.
///
/// Note: no password field. The repository layer is the only thing that
/// ever handles password hashes; everything above that layer should be
/// unable to accidentally leak or log them.
class AppUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  /// Returns a copy of this user with the given fields replaced.
  /// Useful when a screen updates part of the user (e.g. name change)
  /// without mutating the original.
  AppUser copyWith({
    int? id,
    String? name,
    String? email,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'AppUser(id: $id, email: $email, role: ${role.asString})';
}
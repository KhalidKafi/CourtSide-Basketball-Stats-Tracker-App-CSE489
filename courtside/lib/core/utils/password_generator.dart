import 'dart:math';

/// Generates human-readable temporary passwords for admin accounts.
///
/// Format: `Court-NNNN` where N is a digit.
/// Chosen for readability — easy to read aloud, write on paper, or type
/// from a handwritten note when the Super Admin hands credentials over
/// physically. Not suitable for any other use: 10,000 possibilities is
/// trivially brute-forceable; these are meant to be changed after first
/// login (future enhancement), and even as-is they're gated behind an
/// existing auth check on the Super Admin.
class PasswordGenerator {
  PasswordGenerator._();

  static final _rng = Random.secure();

  static String generate() {
    final n = _rng.nextInt(10000);
    final digits = n.toString().padLeft(4, '0');
    return 'Court-$digits';
  }
}
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// SHA-256 + per-user random salt password hashing.
///
/// Storage format: `<salt_hex>$<hash_hex>`
///   - salt: 16 random bytes, hex-encoded (32 chars)
///   - hash: SHA-256(salt_bytes + utf8_password_bytes), hex-encoded (64 chars)
///
/// This is appropriate for a coursework project. A production system would
/// use a purpose-built password hash like bcrypt or argon2 with a tunable
/// work factor — those make brute-forcing slow. SHA-256 is fast, which
/// means an attacker with the DB can try billions of guesses per second.
/// We accept that trade-off here because native bcrypt on Android adds
/// compilation friction that isn't worth it for a CSE489 project.
class PasswordHasher {
  PasswordHasher._(); // prevent instantiation — this is a static-only class

  /// `Random.secure()` uses the OS's cryptographic RNG (on Android: /dev/urandom).
  /// Never use the default `Random()` constructor for security purposes —
  /// it's a deterministic pseudo-random generator and produces predictable
  /// output if you know the seed.
  static final _rng = Random.secure();

  /// Hash a plaintext password for storage in the USERS.password column.
  static String hash(String password) {
    final saltBytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    final saltHex = _toHex(saltBytes);
    final hashHex = _sha256Hex(saltBytes, password);
    return '$saltHex\$$hashHex';
  }

  /// Verify a plaintext password against a `salt$hash` string from the DB.
  /// Returns false for malformed input rather than throwing — a corrupted
  /// password row should fail login, not crash the auth flow.
  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 2) return false;

    final saltHex = parts[0];
    final expectedHashHex = parts[1];

    final saltBytes = _fromHex(saltHex);
    if (saltBytes == null) return false;

    final actualHashHex = _sha256Hex(saltBytes, password);
    return _constantTimeEquals(actualHashHex, expectedHashHex);
  }

  // ─── internals ────────────────────────────────────────────────────────

  static String _sha256Hex(List<int> salt, String password) {
    final pwBytes = utf8.encode(password);
    final combined = <int>[...salt, ...pwBytes];
    return sha256.convert(combined).toString();
  }

  static String _toHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static List<int>? _fromHex(String hex) {
    if (hex.length.isOdd) return null;
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final v = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (v == null) return null;
      bytes.add(v);
    }
    return bytes;
  }

  /// Constant-time string comparison.
  ///
  /// Why: the naive `a == b` short-circuits on the first differing character,
  /// so comparing the "right" password takes microseconds longer than a
  /// "wrong" one. An attacker timing login attempts across a network could
  /// exploit that to guess the hash one character at a time. This loop
  /// always runs to completion, masking timing differences.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
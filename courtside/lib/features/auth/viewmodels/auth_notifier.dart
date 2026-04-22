import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../models/app_user.dart';
import '../../../repositories/auth_repository.dart';

// ──────────────────────────────────────────────────────────────────────────
// Infrastructure providers
//
// These are the "singletons" of the app. The database provider is
// overridden at startup in main.dart (we build the DB there, after
// running the seeder); the repository is a pure function of the DB,
// so it doesn't need overriding.
// ──────────────────────────────────────────────────────────────────────────

/// Singleton drift database.
///
/// We `throw UnimplementedError` in the default body because this provider
/// MUST be overridden in `main.dart` with a real database instance (which
/// we construct after running the seeder). If `main.dart` forgets to
/// override, we fail loudly at startup instead of silently using a broken
/// default.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in main() '
    'with ProviderScope(overrides: [...])',
  );
});

/// The auth repository — a pure function of the database, so no override
/// is needed. Riverpod wires it up automatically.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(appDatabaseProvider));
});

// ──────────────────────────────────────────────────────────────────────────
// Auth state
// ──────────────────────────────────────────────────────────────────────────

/// The snapshot of auth state at any moment.
///
/// - `user`: the logged-in user, or null if logged out / not yet loaded.
/// - `isLoading`: true during an in-flight login/register/session-load.
/// - `error`: the last error message, or null. Cleared on success or on
///   the next request.
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  /// The default state: logged out, not loading, no error.
  const AuthState.initial() : this();

  /// Classic copy-with. `clearUser` and `clearError` are explicit flags
  /// because you can't distinguish "don't change this field" (pass `null`)
  /// from "set this field to null" (pass... null) using just a named
  /// parameter. Common pattern.
  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// AuthNotifier
//
// The Notifier is the brain. It owns the state, exposes methods that
// mutate it, and delegates data work to the repository.
//
// The UI never touches the notifier directly; it does `ref.watch(
// authNotifierProvider)` to read state, and `ref.read(authNotifierProvider
// .notifier).login(...)` to call methods.
// ──────────────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  /// Riverpod calls `build` once when the provider is first read. Return
  /// the initial state. We don't load the session here — session loading
  /// is async and we want the SplashScreen to await it explicitly.
  @override
  AuthState build() => const AuthState.initial();

  /// Shortcut — the repository is the same for every method, so read it
  /// once via a getter. `ref.read` (not `watch`) because we don't want
  /// this notifier to rebuild when the repository "changes" (it won't,
  /// but the type system doesn't know that).
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Called once at app startup by the SplashScreen to restore a saved
  /// session (or confirm there is none).
  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final user = await _repo.loadSession();
    state = AuthState(user: user, isLoading: false);
  }

  /// Attempts to log in with the given credentials. Returns true on
  /// success, false on failure — the caller can then read `state.error`
  /// for the message.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.login(email: email, password: password);

    if (result.isSuccess) {
      state = AuthState(user: result.user, isLoading: false);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    }
  }

  /// Registers a new coach and auto-logs-them in on success.
  Future<bool> registerCoach({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.registerCoach(
      name: name,
      email: email,
      password: password,
    );

    if (!result.isSuccess) {
      state = state.copyWith(isLoading: false, error: result.error);
      return false;
    }

    // Registration succeeded. Immediately log the user in so they land
    // on the dashboard, not back at the login screen.
    final loginResult = await _repo.login(email: email, password: password);
    if (loginResult.isSuccess) {
      state = AuthState(user: loginResult.user, isLoading: false);
      return true;
    }

    // Extremely unlikely — registered but can't log in. Report it.
    state = state.copyWith(isLoading: false, error: loginResult.error);
    return false;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(user: null);
  }

  /// Lets the UI dismiss a stale error after showing it in a SnackBar.
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

/// The provider the UI subscribes to. The weird two-type-parameter syntax
/// is how Riverpod distinguishes the Notifier class from its state type.
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
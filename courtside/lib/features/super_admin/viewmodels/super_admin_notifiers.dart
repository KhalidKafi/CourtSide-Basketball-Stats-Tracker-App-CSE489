import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_user.dart';
import '../../../repositories/providers.dart';
import '../../../repositories/super_admin_repository.dart';

// ─── Streaming reads ────────────────────────────────────────────────────

final allAdminsProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(superAdminRepositoryProvider).watchAllAdmins();
});

final unresolvedFlagsProvider = StreamProvider<List<FlagItem>>((ref) {
  return ref.watch(superAdminRepositoryProvider).watchUnresolvedFlags();
});

// ─── Actions ────────────────────────────────────────────────────────────

class SuperAdminActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<({bool ok, String? error})> createAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await ref
          .read(superAdminRepositoryProvider)
          .createAdmin(name: name, email: email, password: password);
      if (result.isSuccess) {
        state = const AsyncValue.data(null);
        return (ok: true, error: null);
      } else {
        state = AsyncValue.error(result.error!, StackTrace.current);
        return (ok: false, error: result.error);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return (ok: false, error: e.toString());
    }
  }

  Future<bool> resetPassword(int adminId, String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(superAdminRepositoryProvider)
          .resetAdminPassword(adminId, newPassword);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteAdmin(int adminId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(superAdminRepositoryProvider).deleteAdmin(adminId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteCoach(int coachId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(superAdminRepositoryProvider).deleteCoach(coachId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteTeam(int teamId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(superAdminRepositoryProvider).deleteTeam(teamId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteGame(int gameId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(superAdminRepositoryProvider).deleteGame(gameId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> dismissFlag({
    required int flagId,
    required int superAdminId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(superAdminRepositoryProvider)
          .dismissFlag(flagId: flagId, superAdminId: superAdminId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteFlagTarget({
    required FlagItem flag,
    required int superAdminId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(superAdminRepositoryProvider).deleteFlagTarget(
            flag: flag,
            superAdminId: superAdminId,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  String? get lastError =>
      state.hasError ? state.error.toString() : null;
}

final superAdminActionsProvider =
    AsyncNotifierProvider<SuperAdminActionsNotifier, void>(
        SuperAdminActionsNotifier.new);
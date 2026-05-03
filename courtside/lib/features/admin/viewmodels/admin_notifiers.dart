import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../models/app_user.dart';
import '../../../repositories/providers.dart';
import '../../auth/viewmodels/auth_notifier.dart';

// ─── Streaming reads ────────────────────────────────────────────────────

final allCoachesProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllCoaches();
});

final systemCountsProvider = StreamProvider<SystemCounts>((ref) {
  return ref.watch(adminRepositoryProvider).watchSystemCounts();
});

final coachByIdProvider =
    FutureProvider.family<AppUser?, int>((ref, id) {
  return ref.watch(adminRepositoryProvider).findCoachById(id);
});

final coachUserRowProvider =
    StreamProvider.family<User?, int>((ref, coachId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.users)..where((u) => u.id.equals(coachId)))
      .watchSingleOrNull();
});

// ─── Actions ────────────────────────────────────────────────────────────

class AdminActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> setCoachDisabled(int coachId, bool disabled) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(adminRepositoryProvider)
          .setCoachDisabled(coachId, disabled);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> flagTeam({
    required int teamId,
    required int adminId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(adminRepositoryProvider).flagTeam(
            teamId: teamId,
            adminId: adminId,
            reason: reason,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> flagGame({
    required int gameId,
    required int adminId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(adminRepositoryProvider).flagGame(
            gameId: gameId,
            adminId: adminId,
            reason: reason,
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

final adminActionsProvider =
    AsyncNotifierProvider<AdminActionsNotifier, void>(
        AdminActionsNotifier.new);
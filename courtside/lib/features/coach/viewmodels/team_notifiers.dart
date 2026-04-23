import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/player.dart';
import '../../../models/team.dart';
import '../../../repositories/providers.dart';
import '../../auth/viewmodels/auth_notifier.dart';

// ──────────────────────────────────────────────────────────────────────────
// Streaming read providers
// ──────────────────────────────────────────────────────────────────────────

/// Auto-updating list of teams owned by the given coach. Usage from UI:
///
///   final teamsAsync = ref.watch(teamsForCoachProvider(coachId));
///   teamsAsync.when(
///     data: (teams) => ...render list...,
///     loading: () => const CircularProgressIndicator(),
///     error: (e, _) => Text('Error: $e'),
///   );
///
/// `.family` makes this a "parameterized" provider — one stream per
/// coachId. Different coaches get different streams, which are cached
/// independently.
final teamsForCoachProvider =
    StreamProvider.family<List<Team>, int>((ref, coachId) {
  return ref.watch(teamRepositoryProvider).watchTeamsForCoach(coachId);
});

/// Auto-updating list of players for a team.
final playersForTeamProvider =
    StreamProvider.family<List<Player>, int>((ref, teamId) {
  return ref.watch(playerRepositoryProvider).watchPlayersForTeam(teamId);
});

/// One-shot team lookup by ID. Used by the team detail screen to render
/// its AppBar title and the "home court" subtitle. Not a stream because
/// team details rarely change while the user is viewing them; if they
/// do (via an edit), we'll handle the refresh explicitly.
final teamByIdProvider = FutureProvider.family<Team?, int>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).findById(teamId);
});

/// Streaming total count of players across all teams a coach owns.
final totalPlayersForCoachProvider =
    StreamProvider.family<int, int>((ref, coachId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchTotalPlayersForCoach(coachId);
});

// ──────────────────────────────────────────────────────────────────────────
// Team actions (create / update / delete)
// ──────────────────────────────────────────────────────────────────────────

/// AsyncNotifier — the async sibling of Notifier. State is `AsyncValue<void>`
/// because team actions don't return data to the UI; they either succeed
/// (state becomes AsyncValue.data(null)) or fail (AsyncValue.error).
class TeamActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // No initial work. Starting state is AsyncValue.data(null).
  }

  Future<bool> createTeam({
    required int coachId,
    required String name,
    required String season,
    required String homeCourt,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(teamRepositoryProvider).createTeam(
            coachId: coachId,
            name: name,
            season: season,
            homeCourt: homeCourt,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateTeam({
    required int id,
    String? name,
    String? season,
    String? homeCourt,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(teamRepositoryProvider).updateTeam(
            id: id,
            name: name,
            season: season,
            homeCourt: homeCourt,
          );
      // Invalidate the one-shot lookup so the detail screen re-fetches.
      ref.invalidate(teamByIdProvider(id));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteTeam(int id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(teamRepositoryProvider).deleteTeam(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Convenience getter for UI — last error message, or null.
  String? get lastError {
    return state.hasError ? state.error.toString() : null;
  }
}

final teamActionsProvider =
    AsyncNotifierProvider<TeamActionsNotifier, void>(TeamActionsNotifier.new);

// ──────────────────────────────────────────────────────────────────────────
// Player actions (create / update / delete)
// ──────────────────────────────────────────────────────────────────────────

class PlayerActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns (success, errorMessageOrNull). The error message comes from
  /// PlayerWriteResult (for domain errors like "jersey taken") or from
  /// the caught exception (for DB errors).
  Future<({bool ok, String? error})> createPlayer({
    required int teamId,
    required String name,
    required int jerseyNumber,
    required PlayerPosition position,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result =
          await ref.read(playerRepositoryProvider).createPlayer(
                teamId: teamId,
                name: name,
                jerseyNumber: jerseyNumber,
                position: position,
              );
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

  Future<({bool ok, String? error})> updatePlayer({
    required int id,
    required int teamId,
    String? name,
    int? jerseyNumber,
    PlayerPosition? position,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result =
          await ref.read(playerRepositoryProvider).updatePlayer(
                id: id,
                teamId: teamId,
                name: name,
                jerseyNumber: jerseyNumber,
                position: position,
              );
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

  Future<bool> deletePlayer(int id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(playerRepositoryProvider).deletePlayer(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final playerActionsProvider = AsyncNotifierProvider<PlayerActionsNotifier, void>(
    PlayerActionsNotifier.new);
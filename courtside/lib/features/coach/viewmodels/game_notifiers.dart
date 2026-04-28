import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/game.dart';
import '../../../models/recent_game.dart';
import '../../../repositories/providers.dart';
import '../../auth/viewmodels/auth_notifier.dart';

// Streaming read providers


/// Auto-updating list of all games for a team, most recent first.
final gamesForTeamProvider =
    StreamProvider.family<List<Game>, int>((ref, teamId) {
  return ref.watch(gameRepositoryProvider).watchGamesForTeam(teamId);
});

/// The in-progress game for a team, if any. Null when none.
/// Used by the team detail screen to show "Resume game" instead of
/// "New game" when there's an unfinished session.
final inProgressGameForTeamProvider =
    StreamProvider.family<Game?, int>((ref, teamId) {
  return ref.watch(gameRepositoryProvider).watchInProgressGameForTeam(teamId);
});

/// One-shot lookup. Used by the live game screen header — the game
/// itself doesn't change during play except via dedicated notifier
/// methods, so a stream isn't necessary.
final gameByIdProvider = FutureProvider.family<Game?, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).findById(gameId);
});

/// Streams the most recent games (with team names) across all of a coach's
/// teams. Used by the Coach Dashboard's "Recent Games" section.
final recentGamesForCoachProvider =
    StreamProvider.family<List<RecentGame>, int>((ref, coachId) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .watchRecentGamesWithTeamNameForCoach(coachId: coachId, limit: 5)
      .map((tuples) {
    return tuples.map((t) {
      final r = t.game;
      final game = Game(
        id: r.id,
        opponent: r.opponent,
        date: DateTime.parse(r.date),
        homeAway: HomeAwayX.fromCode(r.homeAway),
        result: r.result == null ? null : GameResultX.fromCode(r.result!),
        opponentScore: r.opponentScore,
        teamId: r.teamId,
        isFinished: r.isFinished,
        createdAt: r.createdAt,
      );
      return RecentGame(game: game, teamName: t.teamName);
    }).toList();
  });
});


// Game actions (create / delete)
// Note: live game actions (logging stats, undo, end game) live in a
// separate LiveGameNotifier in Step 8 — those need rich in-memory state
// for the undo buffer and aren't a fit for AsyncNotifier<void>.


class GameActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates a new game. Returns the new game's ID on success, or null
  /// on failure. The caller (the new-game form) uses this ID to navigate
  /// to the live game screen.
  Future<int?> createGame({
    required int teamId,
    required String opponent,
    required DateTime date,
    required HomeAway homeAway,
    required List<int> playerIds,
  }) async {
    state = const AsyncValue.loading();
    try {
      final newId = await ref.read(gameRepositoryProvider).createGame(
            teamId: teamId,
            opponent: opponent,
            date: date,
            homeAway: homeAway,
            playerIds: playerIds,
          );
      state = const AsyncValue.data(null);
      return newId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteGame(int id) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(gameRepositoryProvider).deleteGame(id);
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

final gameActionsProvider =
    AsyncNotifierProvider<GameActionsNotifier, void>(GameActionsNotifier.new);
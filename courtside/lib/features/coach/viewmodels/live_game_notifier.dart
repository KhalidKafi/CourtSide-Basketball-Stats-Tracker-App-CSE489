import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../auth/viewmodels/auth_notifier.dart';
import '../../../core/database/app_database.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../../repositories/providers.dart';


// Action types — what a coach can log during a live game

enum PlayerActionType {
  twoPtMade,
  twoPtMissed,
  threePtMade,
  threePtMissed,
  ftMade,
  ftMissed,
}

extension PlayerActionTypeX on PlayerActionType {
  /// Points awarded by this action when made. Misses always give 0.
  int get points {
    switch (this) {
      case PlayerActionType.twoPtMade:
        return 2;
      case PlayerActionType.threePtMade:
        return 3;
      case PlayerActionType.ftMade:
        return 1;
      case PlayerActionType.twoPtMissed:
      case PlayerActionType.threePtMissed:
      case PlayerActionType.ftMissed:
        return 0;
    }
  }

  /// Short label for action buttons.
  String get label {
    switch (this) {
      case PlayerActionType.twoPtMade:
        return '+2 Made';
      case PlayerActionType.twoPtMissed:
        return '+2 Miss';
      case PlayerActionType.threePtMade:
        return '+3 Made';
      case PlayerActionType.threePtMissed:
        return '+3 Miss';
      case PlayerActionType.ftMade:
        return 'FT Made';
      case PlayerActionType.ftMissed:
        return 'FT Miss';
    }
  }
}


// Last-action record — supports single-step undo


enum LastActionKind { playerStat, opponentScore }

/// The most recent reversible action. One class instead of a sealed
/// hierarchy — simpler and avoids analyzer issues with pattern matching.
/// Only the fields relevant to `kind` are populated; the rest are null.
class LastAction {
  final LastActionKind kind;
  final int? playerId;
  final PlayerActionType? type;
  final int? delta;

  const LastAction.playerStat({
    required int this.playerId,
    required PlayerActionType this.type,
  })  : kind = LastActionKind.playerStat,
        delta = null;

  const LastAction.opponentScore(int this.delta)
      : kind = LastActionKind.opponentScore,
        playerId = null,
        type = null;
}


// LiveGameState — the snapshot the UI watches

class LiveGameState {
  /// Set once the notifier has loaded the game and its players.
  final Game? game;
  final List<Player> players;

  /// player_id → GameStatRow.  Lookups are O(1).
  final Map<int, GameStatRow> statsByPlayerId;

  /// Currently active player. Null until the coach selects one.
  final int? activePlayerId;

  /// The most recent reversible action, or null if nothing to undo.
  final LastAction? lastAction;

  /// True while a write to the DB is in flight. Disables further taps.
  final bool isLogging;

  const LiveGameState({
    this.game,
    this.players = const [],
    this.statsByPlayerId = const {},
    this.activePlayerId,
    this.lastAction,
    this.isLogging = false,
  });

  // ─── Derived getters ────────────────────────────────────────────────────

  /// Sum of all players' points = our team's score.
  int get teamScore {
    var total = 0;
    for (final s in statsByPlayerId.values) {
      total += s.twoPtMade * 2 + s.threePtMade * 3 + s.ftMade;
    }
    return total;
  }

  int get opponentScore => game?.opponentScore ?? 0;

  /// Active player object, or null.
  Player? get activePlayer {
    if (activePlayerId == null) return null;
    return players.firstWhere(
      (p) => p.id == activePlayerId,
      orElse: () => players.first, // shouldn't happen, defensive
    );
  }

  /// Per-player live stat summary, used by the player-selector chips.
  /// Returns 0 if the player has no stat row yet (also shouldn't happen).
  int pointsFor(int playerId) {
    final s = statsByPlayerId[playerId];
    if (s == null) return 0;
    return s.twoPtMade * 2 + s.threePtMade * 3 + s.ftMade;
  }

  bool get canUndo => lastAction != null && !isLogging;
  bool get canLogAction => activePlayerId != null && !isLogging;

  LiveGameState copyWith({
    Game? game,
    List<Player>? players,
    Map<int, GameStatRow>? statsByPlayerId,
    int? activePlayerId,
    LastAction? lastAction,
    bool? isLogging,
    bool clearActivePlayer = false,
    bool clearLastAction = false,
  }) {
    return LiveGameState(
      game: game ?? this.game,
      players: players ?? this.players,
      statsByPlayerId: statsByPlayerId ?? this.statsByPlayerId,
      activePlayerId: clearActivePlayer
          ? null
          : (activePlayerId ?? this.activePlayerId),
      lastAction:
          clearLastAction ? null : (lastAction ?? this.lastAction),
      isLogging: isLogging ?? this.isLogging,
    );
  }
}


// The notifier


class LiveGameNotifier extends FamilyNotifier<LiveGameState, int> {
  /// `arg` here is the gameId, supplied via `.family`.
  @override
  LiveGameState build(int gameId) {
    // Subscribe to the streaming providers so our state stays in sync
    // when the DB changes (e.g., another action committed).
    ref.listen<AsyncValue<Game?>>(_gameStreamProvider(gameId), (_, next) {
      next.whenData((g) {
        if (g != null) state = state.copyWith(game: g);
      });
    });

    ref.listen<AsyncValue<List<Player>>>(
      _playersStreamProvider(gameId),
      (_, next) {
        next.whenData((list) => state = state.copyWith(players: list));
      },
    );

    ref.listen<AsyncValue<List<GameStatRow>>>(
      _statsStreamProvider(gameId),
      (_, next) {
        next.whenData((rows) {
          state = state.copyWith(
            statsByPlayerId: {for (final r in rows) r.playerId: r},
          );
        });
      },
    );

    return const LiveGameState();
  }

  // ─── UI commands ─────────

  void selectPlayer(int playerId) {
    if (state.isLogging) return;
    state = state.copyWith(activePlayerId: playerId);
  }

  /// Logs a player action. Optimistically updates the in-memory state,
  /// then persists to the DB. If the DB write fails, we don't roll back
  /// (drift will throw and we propagate); the streaming query will
  /// re-sync on next emission.
  Future<void> logPlayerAction(PlayerActionType type) async {
    final activeId = state.activePlayerId;
    if (activeId == null || state.isLogging) return;

    final db = ref.read(appDatabaseProvider);
    final stat = state.statsByPlayerId[activeId];
    if (stat == null) return;

    state = state.copyWith(isLogging: true);

    try {
      // Compute the new stat row
      final updated = _applyAction(stat, type, 1);
      // Persist
      await db.updateGameStat(stat.id, updated);
      // The streaming query will fire shortly with the new row, but to
      // make the UI feel instant, also patch our in-memory map.
      state = state.copyWith(
        statsByPlayerId: {
          ...state.statsByPlayerId,
          activeId: _materializeRow(stat, updated),
        },
        lastAction: LastAction.playerStat(playerId: activeId, type: type),
        isLogging: false,
      );
    } catch (_) {
      state = state.copyWith(isLogging: false);
      rethrow;
    }
  }

  /// Bumps the opponent score and records the action for undo.
  Future<void> bumpOpponentScore(int delta) async {
    final game = state.game;
    if (game == null || state.isLogging) return;
    state = state.copyWith(isLogging: true);
    try {
      await ref.read(gameRepositoryProvider).bumpOpponentScore(
            gameId: game.id,
            delta: delta,
          );
      // Optimistic patch on game.
      state = state.copyWith(
        game: game.copyWith(opponentScore: game.opponentScore + delta),
        lastAction: LastAction.opponentScore(delta),
        isLogging: false,
      );
    } catch (_) {
      state = state.copyWith(isLogging: false);
      rethrow;
    }
  }

  /// Reverses the most recent action (single-step). Clears `lastAction`
  /// so a second tap is a no-op.
  Future<void> undoLastAction() async {
    final last = state.lastAction;
    if (last == null || state.isLogging) return;

    state = state.copyWith(isLogging: true);
    try {
      switch (last.kind) {
        case LastActionKind.playerStat:
          final playerId = last.playerId!;
          final type = last.type!;
          final stat = state.statsByPlayerId[playerId];
          if (stat == null) {
            state = state.copyWith(isLogging: false, clearLastAction: true);
            return;
          }
          final reverted = _applyAction(stat, type, -1);
          await ref
              .read(appDatabaseProvider)
              .updateGameStat(stat.id, reverted);
          state = state.copyWith(
            statsByPlayerId: {
              ...state.statsByPlayerId,
              playerId: _materializeRow(stat, reverted),
            },
            isLogging: false,
            clearLastAction: true,
          );
          break;

        case LastActionKind.opponentScore:
          final delta = last.delta!;
          final game = state.game;
          if (game == null) {
            state = state.copyWith(isLogging: false, clearLastAction: true);
            return;
          }
          await ref.read(gameRepositoryProvider).bumpOpponentScore(
                gameId: game.id,
                delta: -delta,
              );
          state = state.copyWith(
            game: game.copyWith(
              opponentScore: game.opponentScore - delta,
            ),
            isLogging: false,
            clearLastAction: true,
          );
          break;
      }
    } catch (_) {
      state = state.copyWith(isLogging: false);
      rethrow;
    }
  }

  /// Ends the game. Sets isFinished=true and the result.
  /// Caller may pass a final opponent score (typed in the End Game dialog)
  /// to override whatever the live strip accumulated.
  Future<void> endGame({
    required GameResult result,
    int? finalOpponentScore,
  }) async {
    final game = state.game;
    if (game == null) return;

    await ref.read(gameRepositoryProvider).endGame(
          gameId: game.id,
          result: result,
          opponentScore: finalOpponentScore,
        );
  }

  // ─── Helpers ──────

  /// Builds a `GameStatsCompanion` representing the row after applying
  /// `delta` (+1 to log, -1 to undo) to the column for `type`.
  GameStatsCompanion _applyAction(
    GameStatRow row,
    PlayerActionType type,
    int delta,
  ) {
    switch (type) {
      case PlayerActionType.twoPtMade:
        return GameStatsCompanion(twoPtMade: Value(row.twoPtMade + delta));
      case PlayerActionType.twoPtMissed:
        return GameStatsCompanion(
            twoPtMissed: Value(row.twoPtMissed + delta));
      case PlayerActionType.threePtMade:
        return GameStatsCompanion(
            threePtMade: Value(row.threePtMade + delta));
      case PlayerActionType.threePtMissed:
        return GameStatsCompanion(
            threePtMissed: Value(row.threePtMissed + delta));
      case PlayerActionType.ftMade:
        return GameStatsCompanion(ftMade: Value(row.ftMade + delta));
      case PlayerActionType.ftMissed:
        return GameStatsCompanion(ftMissed: Value(row.ftMissed + delta));
    }
  }

  /// Builds a hypothetical "what the row will look like after the
  /// update" — used to optimistically patch the in-memory state without
  /// waiting for the stream re-emission. The actual DB row will arrive
  /// via the streaming query and overwrite this.
  GameStatRow _materializeRow(GameStatRow current, GameStatsCompanion ch) {
    return GameStatRow(
      id: current.id,
      gameId: current.gameId,
      playerId: current.playerId,
      twoPtMade: ch.twoPtMade.present ? ch.twoPtMade.value : current.twoPtMade,
      twoPtMissed: ch.twoPtMissed.present
          ? ch.twoPtMissed.value
          : current.twoPtMissed,
      threePtMade: ch.threePtMade.present
          ? ch.threePtMade.value
          : current.threePtMade,
      threePtMissed: ch.threePtMissed.present
          ? ch.threePtMissed.value
          : current.threePtMissed,
      ftMade: ch.ftMade.present ? ch.ftMade.value : current.ftMade,
      ftMissed: ch.ftMissed.present ? ch.ftMissed.value : current.ftMissed,
    );
  }
}


// Internal streaming providers — the notifier subscribes to these

/// Stream of the game itself. We use the in-progress watcher because it
/// already filters by id once the notifier is bound to a specific gameId.
final _gameStreamProvider =
    StreamProvider.family<Game?, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).watchGameById(gameId);
});

final _playersStreamProvider =
    StreamProvider.family<List<Player>, int>((ref, gameId) async* {
  // Resolve the game first to know its team, then stream players for that team.
  final game = await ref.read(gameRepositoryProvider).findById(gameId);
  if (game == null) {
    yield <Player>[];
    return;
  }
  yield* ref
      .read(playerRepositoryProvider)
      .watchPlayersForTeam(game.teamId);
});

final _statsStreamProvider =
    StreamProvider.family<List<GameStatRow>, int>((ref, gameId) {
  return ref.watch(appDatabaseProvider).watchStatsForGame(gameId);
});


// Public provider

final liveGameNotifierProvider =
    NotifierProvider.family<LiveGameNotifier, LiveGameState, int>(
  LiveGameNotifier.new,
);
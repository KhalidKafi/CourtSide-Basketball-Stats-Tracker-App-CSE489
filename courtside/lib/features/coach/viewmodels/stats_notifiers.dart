import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/stats_calculator.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../../../repositories/providers.dart';

// ──────────────────────────────────────────────────────────────────────────
// Game summary — stats for one specific finished game
// ──────────────────────────────────────────────────────────────────────────

/// Result combining a game's metadata with its per-player stat rows.
class GameSummaryData {
  final Game game;
  final List<Player> players;
  final Map<int, GameStatRow> statsByPlayerId;

  const GameSummaryData({
    required this.game,
    required this.players,
    required this.statsByPlayerId,
  });

  int get teamScore =>
      StatsCalculator.teamScoreFromStats(statsByPlayerId.values);
}

/// Loads everything needed to render a game summary screen.
final gameSummaryProvider =
    FutureProvider.family<GameSummaryData?, int>((ref, gameId) async {
  final gameRepo = ref.watch(gameRepositoryProvider);
  final playerRepo = ref.watch(playerRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);

  final game = await gameRepo.findById(gameId);
  if (game == null) return null;

  final players = await playerRepo.getPlayersForTeam(game.teamId);
  final statRows = await db.getStatsForGame(gameId);

  final statsByPlayerId = {
    for (final s in statRows) s.playerId: s,
  };

  return GameSummaryData(
    game: game,
    players: players,
    statsByPlayerId: statsByPlayerId,
  );
});

// ──────────────────────────────────────────────────────────────────────────
// Season analytics — aggregated stats for all finished games of a team
// ──────────────────────────────────────────────────────────────────────────

/// One-game summary used on the points-per-game chart. Each bar = one game.
class GamePointsEntry {
  final int gameId;
  final DateTime date;
  final String opponent;
  final int teamPoints;
  final int opponentPoints;
  final GameResult? result;

  const GamePointsEntry({
    required this.gameId,
    required this.date,
    required this.opponent,
    required this.teamPoints,
    required this.opponentPoints,
    required this.result,
  });
}

/// Per-player season totals, used on the leaderboard.
class LeaderboardEntry {
  final Player player;
  final PlayerSeasonAggregate aggregate;

  const LeaderboardEntry({required this.player, required this.aggregate});
}

class SeasonAnalytics {
  final int gamesPlayed;
  final int wins;
  final int losses;
  final double avgPointsPerGame;
  final double? teamFgPct;
  final List<GamePointsEntry> pointsByGame;
  final List<LeaderboardEntry> leaderboard;

  const SeasonAnalytics({
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.avgPointsPerGame,
    required this.teamFgPct,
    required this.pointsByGame,
    required this.leaderboard,
  });

  double get winPct {
    if (gamesPlayed == 0) return 0;
    return (wins / gamesPlayed) * 100;
  }
}

/// Builds the season analytics data for a team. We do this as a future
/// (not stream) for now — analytics screens are typically opened, viewed,
/// and exited. If we wanted live updates while a game ends, we could
/// switch to a stream later.
final seasonAnalyticsProvider =
    StreamProvider.family<SeasonAnalytics, int>((ref, teamId) async* {
  final db = ref.watch(appDatabaseProvider);
  final playerRepo = ref.watch(playerRepositoryProvider);

  // Fetch the player roster once — we'll reuse it for every emission.
  final players = await playerRepo.getPlayersForTeam(teamId);
  final playersByid = {for (final p in players) p.id: p};

  await for (final tuples in db.watchSeasonStatsForTeam(teamId)) {
    yield _buildAnalytics(teamId, tuples, players, playersByid);
  }
});

SeasonAnalytics _buildAnalytics(
  int teamId,
  List<({GameStatRow stat, GameRow game})> tuples,
  List<Player> players,
  Map<int, Player> playersById,
) {
  // Group rows by gameId so we can compute team totals per game.
  final byGame = <int, List<GameStatRow>>{};
  final gameRows = <int, GameRow>{};
  for (final t in tuples) {
    (byGame[t.game.id] ??= []).add(t.stat);
    gameRows[t.game.id] = t.game;
  }

  // Build per-game points entries.
  final pointsByGame = <GamePointsEntry>[];
  var wins = 0;
  var losses = 0;
  var totalTeamPoints = 0;

  // Sort game IDs by date for the chart.
  final sortedGameIds = gameRows.keys.toList()
    ..sort((a, b) {
      return DateTime.parse(gameRows[a]!.date)
          .compareTo(DateTime.parse(gameRows[b]!.date));
    });

  for (final gameId in sortedGameIds) {
    final g = gameRows[gameId]!;
    final stats = byGame[gameId] ?? const <GameStatRow>[];
    final teamPoints = StatsCalculator.teamScoreFromStats(stats);
    totalTeamPoints += teamPoints;

    final result =
        g.result == null ? null : GameResultX.fromCode(g.result!);
    if (result == GameResult.win) wins++;
    if (result == GameResult.loss) losses++;

    pointsByGame.add(GamePointsEntry(
      gameId: g.id,
      date: DateTime.parse(g.date),
      opponent: g.opponent,
      teamPoints: teamPoints,
      opponentPoints: g.opponentScore,
      result: result,
    ));
  }

  final gamesPlayed = sortedGameIds.length;
  final avg =
      gamesPlayed == 0 ? 0.0 : totalTeamPoints / gamesPlayed;
  final teamFgPct = StatsCalculator.teamFieldGoalPct(
    tuples.map((t) => t.stat),
  );

  // Build leaderboard by aggregating each player's stats across all games.
  final leaderboard = <LeaderboardEntry>[];
  final byPlayer = <int, List<GameStatRow>>{};
  for (final t in tuples) {
    (byPlayer[t.stat.playerId] ??= []).add(t.stat);
  }
  for (final p in players) {
    final rows = byPlayer[p.id] ?? const <GameStatRow>[];
    final agg = StatsCalculator.sumPlayerStats(rows);
    leaderboard.add(LeaderboardEntry(player: p, aggregate: agg));
  }
  leaderboard.sort(
      (a, b) => b.aggregate.totalPoints.compareTo(a.aggregate.totalPoints));

  return SeasonAnalytics(
    gamesPlayed: gamesPlayed,
    wins: wins,
    losses: losses,
    avgPointsPerGame: avg,
    teamFgPct: teamFgPct,
    pointsByGame: pointsByGame,
    leaderboard: leaderboard,
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Player profile — one player's season stats + per-game breakdown
// ──────────────────────────────────────────────────────────────────────────

class PlayerProfileData {
  final Player player;
  final PlayerSeasonAggregate aggregate;
  final List<GamePointsEntry> perGamePoints;

  const PlayerProfileData({
    required this.player,
    required this.aggregate,
    required this.perGamePoints,
  });
}

final playerProfileProvider =
    StreamProvider.family<PlayerProfileData?, int>((ref, playerId) async* {
  final playerRepo = ref.watch(playerRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);

  final player = await playerRepo.findById(playerId);
  if (player == null) {
    yield null;
    return;
  }

  await for (final tuples in db.watchSeasonStatsForPlayer(playerId)) {
    final agg = StatsCalculator.sumPlayerStats(tuples.map((t) => t.stat));

    final perGame = tuples.map((t) {
      return GamePointsEntry(
        gameId: t.game.id,
        date: DateTime.parse(t.game.date),
        opponent: t.game.opponent,
        teamPoints: StatsCalculator.totalPoints(t.stat),
        opponentPoints: t.game.opponentScore,
        result: t.game.result == null
            ? null
            : GameResultX.fromCode(t.game.result!),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    yield PlayerProfileData(
      player: player,
      aggregate: agg,
      perGamePoints: perGame,
    );
  }
});
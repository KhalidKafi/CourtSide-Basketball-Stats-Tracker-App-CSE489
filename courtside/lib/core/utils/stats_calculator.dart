import '../database/app_database.dart';

/// Pure functions that compute derived basketball stats from raw counts.
/// All formulas are from spec section 11 — never deviate without
/// updating both this file and the spec.
class StatsCalculator {
  StatsCalculator._();

  // ─── Per-game per-player ─────────────────────────────────────────────────

  static int totalPoints(GameStatRow s) {
    return s.twoPtMade * 2 + s.threePtMade * 3 + s.ftMade;
  }

  /// Field Goal % — includes both 2s and 3s. Returns null if there were
  /// no field goal attempts (so callers can render "—" instead of "0.0%").
  static double? fieldGoalPct(GameStatRow s) {
    final made = s.twoPtMade + s.threePtMade;
    final att = made + s.twoPtMissed + s.threePtMissed;
    if (att == 0) return null;
    return (made / att) * 100;
  }

  static double? threePtPct(GameStatRow s) {
    final att = s.threePtMade + s.threePtMissed;
    if (att == 0) return null;
    return (s.threePtMade / att) * 100;
  }

  static double? freeThrowPct(GameStatRow s) {
    final att = s.ftMade + s.ftMissed;
    if (att == 0) return null;
    return (s.ftMade / att) * 100;
  }

  // ─── Per-game team totals ────────────────────────────────────────────────

  /// Sum of all players' points = team's score for the game.
  static int teamScoreFromStats(Iterable<GameStatRow> stats) {
    var total = 0;
    for (final s in stats) {
      total += totalPoints(s);
    }
    return total;
  }

  /// Combined team field goal percentage.
  static double? teamFieldGoalPct(Iterable<GameStatRow> stats) {
    var made = 0;
    var att = 0;
    for (final s in stats) {
      made += s.twoPtMade + s.threePtMade;
      att += s.twoPtMade +
          s.threePtMade +
          s.twoPtMissed +
          s.threePtMissed;
    }
    if (att == 0) return null;
    return (made / att) * 100;
  }

  // ─── Aggregated across multiple stat rows (a player's season) ────────────

  /// Sums multiple stat rows into a single PlayerSeasonAggregate.
  static PlayerSeasonAggregate sumPlayerStats(Iterable<GameStatRow> rows) {
    var twoPtMade = 0;
    var twoPtMissed = 0;
    var threePtMade = 0;
    var threePtMissed = 0;
    var ftMade = 0;
    var ftMissed = 0;
    var games = 0;

    for (final r in rows) {
      twoPtMade += r.twoPtMade;
      twoPtMissed += r.twoPtMissed;
      threePtMade += r.threePtMade;
      threePtMissed += r.threePtMissed;
      ftMade += r.ftMade;
      ftMissed += r.ftMissed;
      games++;
    }

    final totalPoints =
        twoPtMade * 2 + threePtMade * 3 + ftMade;

    final fgMade = twoPtMade + threePtMade;
    final fgAtt =
        twoPtMade + twoPtMissed + threePtMade + threePtMissed;
    final fgPct = fgAtt == 0 ? null : (fgMade / fgAtt) * 100;

    final threeAtt = threePtMade + threePtMissed;
    final threePct =
        threeAtt == 0 ? null : (threePtMade / threeAtt) * 100;

    final ftAtt = ftMade + ftMissed;
    final ftPct = ftAtt == 0 ? null : (ftMade / ftAtt) * 100;

    final ppg = games == 0 ? 0.0 : totalPoints / games;

    return PlayerSeasonAggregate(
      gamesPlayed: games,
      totalPoints: totalPoints,
      pointsPerGame: ppg,
      twoPtMade: twoPtMade,
      twoPtMissed: twoPtMissed,
      threePtMade: threePtMade,
      threePtMissed: threePtMissed,
      ftMade: ftMade,
      ftMissed: ftMissed,
      fgPct: fgPct,
      threePtPct: threePct,
      ftPct: ftPct,
    );
  }
}

/// Aggregated stats for one player across multiple games.
class PlayerSeasonAggregate {
  final int gamesPlayed;
  final int totalPoints;
  final double pointsPerGame;
  final int twoPtMade;
  final int twoPtMissed;
  final int threePtMade;
  final int threePtMissed;
  final int ftMade;
  final int ftMissed;
  final double? fgPct;
  final double? threePtPct;
  final double? ftPct;

  const PlayerSeasonAggregate({
    required this.gamesPlayed,
    required this.totalPoints,
    required this.pointsPerGame,
    required this.twoPtMade,
    required this.twoPtMissed,
    required this.threePtMade,
    required this.threePtMissed,
    required this.ftMade,
    required this.ftMissed,
    required this.fgPct,
    required this.threePtPct,
    required this.ftPct,
  });
}
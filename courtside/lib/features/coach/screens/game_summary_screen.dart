import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/stats_calculator.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../viewmodels/stats_notifiers.dart';

class GameSummaryScreen extends ConsumerWidget {
  const GameSummaryScreen({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(gameSummaryProvider(gameId));

    return dataAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.coachHome),
              ),
            ),
            body: const Center(child: Text('Game not found.')),
          );
        }
        return _SummaryView(data: data, gameId: gameId);
      },
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({required this.data, required this.gameId});
  final GameSummaryData data;
  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = data.game;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.teamGames(game.teamId));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.go(AppRoutes.teamGames(game.teamId)),
          ),
          title: const Text('Game Summary'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResultBanner(data: data),
                const SizedBox(height: 16),
                _GameMetaCard(game: game),
                const SizedBox(height: 24),
                Text(
                  'Player Stats',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                ),
                const SizedBox(height: 12),
                _PlayerStatsTable(data: data),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Result banner — big "WIN" or "LOSS" with final score

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.data});
  final GameSummaryData data;

  @override
  Widget build(BuildContext context) {
    final game = data.game;
    final colorScheme = Theme.of(context).colorScheme;

    final (label, bg, fg) = _styleFor(game, colorScheme);

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${data.teamScore}',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '–',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: fg.withValues(alpha: 0.6)),
                  ),
                ),
                Text(
                  '${game.opponentScore}',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'vs ${game.opponent}',
              style: TextStyle(
                color: fg.withValues(alpha: 0.85),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, Color) _styleFor(Game g, ColorScheme cs) {
    if (!g.isFinished) {
      return ('IN PROGRESS', cs.primary, cs.onPrimary);
    }
    switch (g.result) {
      case GameResult.win:
        return ('WIN', Colors.green.shade100, Colors.green.shade900);
      case GameResult.loss:
        return ('LOSS', Colors.red.shade100, Colors.red.shade900);
      case null:
        return ('FINAL', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}

class _GameMetaCard extends StatelessWidget {
  const _GameMetaCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMMd().format(game.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              game.homeAway == HomeAway.home
                  ? Icons.home_outlined
                  : Icons.flight_takeoff_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(dateStr,
                style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(
              game.homeAway.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


// Per-player stats table

class _PlayerStatsTable extends StatelessWidget {
  const _PlayerStatsTable({required this.data});
  final GameSummaryData data;

  @override
  Widget build(BuildContext context) {
    // Sort players by points descending — top scorers first.
    final sortedPlayers = [...data.players]..sort((a, b) {
        final aStats = data.statsByPlayerId[a.id];
        final bStats = data.statsByPlayerId[b.id];
        final aPts = aStats == null ? 0 : StatsCalculator.totalPoints(aStats);
        final bPts = bStats == null ? 0 : StatsCalculator.totalPoints(bStats);
        return bPts.compareTo(aPts);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 44,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Player')),
              DataColumn(label: Text('PTS'), numeric: true),
              DataColumn(label: Text('FG%'), numeric: true),
              DataColumn(label: Text('3P%'), numeric: true),
              DataColumn(label: Text('FT%'), numeric: true),
            ],
            rows: [
              for (final p in sortedPlayers)
                _buildRow(p, data.statsByPlayerId[p.id]),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(Player player, GameStatRow? stat) {
    final pts = stat == null ? 0 : StatsCalculator.totalPoints(stat);
    final fg = stat == null ? null : StatsCalculator.fieldGoalPct(stat);
    final tp = stat == null ? null : StatsCalculator.threePtPct(stat);
    final ft = stat == null ? null : StatsCalculator.freeThrowPct(stat);

    return DataRow(cells: [
      DataCell(Text('${player.jerseyNumber}')),
      DataCell(Text(player.name)),
      DataCell(Text('$pts')),
      DataCell(Text(_pct(fg))),
      DataCell(Text(_pct(tp))),
      DataCell(Text(_pct(ft))),
    ]);
  }

  String _pct(double? v) {
    if (v == null) return '—';
    return '${v.toStringAsFixed(1)}%';
  }
}
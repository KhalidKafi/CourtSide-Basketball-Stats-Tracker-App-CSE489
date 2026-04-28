import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../models/game.dart';
import '../viewmodels/stats_notifiers.dart';
import '../viewmodels/team_notifiers.dart';

class SeasonAnalyticsScreen extends ConsumerWidget {
  const SeasonAnalyticsScreen({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final analyticsAsync = ref.watch(seasonAnalyticsProvider(teamId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.coachTeamDetail(teamId));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.go(AppRoutes.coachTeamDetail(teamId)),
          ),
          title: teamAsync.when(
            loading: () => const Text('Season Analytics'),
            error: (_, __) => const Text('Season Analytics'),
            data: (team) => Text(team?.name ?? 'Season Analytics'),
          ),
        ),
        body: analyticsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (analytics) {
            if (analytics.gamesPlayed == 0) {
              return const _EmptyState();
            }
            return _AnalyticsView(
              teamId: teamId,
              analytics: analytics,
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView({
    required this.teamId,
    required this.analytics,
  });

  final int teamId;
  final SeasonAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeasonStatsRow(analytics: analytics),
          const SizedBox(height: 16),
          _SecondaryStatsRow(analytics: analytics),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Points per Game'),
          const SizedBox(height: 12),
          _PointsBarChartCard(analytics: analytics),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Player Leaderboard'),
          const SizedBox(height: 12),
          _LeaderboardCard(teamId: teamId, analytics: analytics),
        ],
      ),
    );
  }
}


// Top stat row — W, L, Win%

class _SeasonStatsRow extends StatelessWidget {
  const _SeasonStatsRow({required this.analytics});
  final SeasonAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigStatCard(
            label: 'Wins',
            value: '${analytics.wins}',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigStatCard(
            label: 'Losses',
            value: '${analytics.losses}',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigStatCard(
            label: 'Win %',
            value: '${analytics.winPct.toStringAsFixed(0)}%',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


// Secondary stats — Games, Avg Pts, Team FG%

class _SecondaryStatsRow extends StatelessWidget {
  const _SecondaryStatsRow({required this.analytics});
  final SeasonAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final fg = analytics.teamFgPct;
    return Row(
      children: [
        Expanded(
          child: _SmallStatCard(
            label: 'Games',
            value: '${analytics.gamesPlayed}',
            icon: Icons.sports_basketball_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SmallStatCard(
            label: 'Avg PTS',
            value: analytics.avgPointsPerGame.toStringAsFixed(1),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SmallStatCard(
            label: 'Team FG',
            value: fg == null ? '—' : '${fg.toStringAsFixed(1)}%',
            icon: Icons.center_focus_strong_outlined,
          ),
        ),
      ],
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  const _SmallStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


//-------------------------- Points-per-game bar chart--------------------------------------


class _PointsBarChartCard extends StatelessWidget {
  const _PointsBarChartCard({required this.analytics});
  final SeasonAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = analytics.pointsByGame;

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No completed games yet.')),
        ),
      );
    }

    // Compute Y axis max with some headroom so the tallest bar isn't
    // touching the top of the chart.
    final maxY = entries.fold<int>(0, (m, e) => e.teamPoints > m ? e.teamPoints : m);
    final yMax = (maxY * 1.2).ceilToDouble().clamp(20, 999).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
        child: SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    final entry = entries[group.x];
                    return BarTooltipItem(
                      'vs ${entry.opponent}\n${entry.teamPoints}-${entry.opponentPoints}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      // Show date as "Apr 28" — short to fit under each bar.
                      final d = entries[i].date;
                      final label =
                          DateFormat.MMMd().format(d);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: yMax / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yMax / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].teamPoints.toDouble(),
                        width: 18,
                        color: _colorForResult(
                          entries[i].result,
                          colorScheme,
                        ),
                        borderRadius:
                            const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorForResult(GameResult? result, ColorScheme cs) {
    switch (result) {
      case GameResult.win:
        return Colors.green;
      case GameResult.loss:
        return Colors.red;
      case null:
        return cs.outline;
    }
  }
}


//------------------------- Leaderboard---------------------------------------

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.teamId,
    required this.analytics,
  });

  final int teamId;
  final SeasonAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final entries = analytics.leaderboard;

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No players yet.')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              _LeaderboardRow(
                rank: i + 1,
                entry: entries[i],
                onTap: () => context.go(
                  AppRoutes.playerProfile(teamId, entries[i].player.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.onTap,
  });

  final int rank;
  final LeaderboardEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final agg = entry.aggregate;
    final fg = agg.fgPct;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1
                    ? Colors.amber
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: rank == 1
                      ? Colors.black
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Jersey number
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.player.jerseyNumber}',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + secondary line
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.player.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${agg.gamesPlayed} GP  ·  ${agg.pointsPerGame.toStringAsFixed(1)} PPG'
                    '${fg == null ? "" : "  ·  ${fg.toStringAsFixed(0)}% FG"}',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Total points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${agg.totalPoints}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'PTS',
                  style:
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


//------------------- Misc small widgets-----------------------------


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 72, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No completed games yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a game to see season analytics here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:printing/printing.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/stats_calculator.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../../models/team.dart';
import '../pdf/player_profile_pdf.dart';
import '../viewmodels/stats_notifiers.dart';
import '../viewmodels/team_notifiers.dart';

class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({
    super.key,
    required this.teamId,
    required this.playerId,
  });

  final int teamId;
  final int playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(playerProfileProvider(playerId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.teamAnalytics(teamId));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.teamAnalytics(teamId)),
          ),
          title: dataAsync.when(
            loading: () => const Text('Player'),
            error: (_, __) => const Text('Player'),
            data: (d) => Text(d?.player.name ?? 'Player'),
          ),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final teamAsync = ref.watch(teamByIdProvider(teamId));
                return IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                  onPressed: () => _exportPdf(
                    context,
                    teamAsync.value,
                    dataAsync.value,
                  ),
                );
              },
            ),
          ],
        ),
        body: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (data) {
            if (data == null) {
              return const _PlayerGoneBlock();
            }
            return _ProfileBody(data: data);
          },
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    Team? team,
    PlayerProfileData? data,
  ) async {
    if (team == null || data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the data to load.')),
      );
      return;
    }

    final action = await showModalBottomSheet<_ExportAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Save or print PDF'),
              subtitle: const Text('Open in print preview'),
              onTap: () => Navigator.pop(ctx, _ExportAction.print),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share PDF...'),
              subtitle: const Text('Send via apps installed on your device'),
              onTap: () => Navigator.pop(ctx, _ExportAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    try {
      final doc = await PlayerProfilePdf.build(
        team: team,
        data: data,
      );
      final bytes = await doc.save();
      final filename =
          'CourtSide_${data.player.name}_${team.season}.pdf'
              .replaceAll(' ', '_');

      if (action == _ExportAction.print) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: filename,
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate PDF: $e')),
      );
    }
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data});
  final PlayerProfileData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerHeaderCard(player: data.player, agg: data.aggregate),
          const SizedBox(height: 16),
          _PrimaryStatsRow(agg: data.aggregate),
          const SizedBox(height: 12),
          _ShootingPercentagesRow(agg: data.aggregate),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Points per Game'),
          const SizedBox(height: 12),
          _PerGameChartCard(perGame: data.perGamePoints),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Game History'),
          const SizedBox(height: 12),
          _GameHistoryCard(perGame: data.perGamePoints),
        ],
      ),
    );
  }
}

//================ Header card — name, jersey, position ===============================

class _PlayerHeaderCard extends StatelessWidget {
  const _PlayerHeaderCard({required this.player, required this.agg});
  final Player player;
  final PlayerSeasonAggregate agg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Big jersey badge
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${player.jerseyNumber}',
                style: TextStyle(
                  color: colorScheme.primaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    player.position.displayName,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${agg.gamesPlayed} games played',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


//================Primary stats — Points, PPG===============================


class _PrimaryStatsRow extends StatelessWidget {
  const _PrimaryStatsRow({required this.agg});
  final PlayerSeasonAggregate agg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BigStatCard(
            label: 'Total Points',
            value: '${agg.totalPoints}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigStatCard(
            label: 'Points / Game',
            value: agg.pointsPerGame.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
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


//================ Shooting percentages===============================

class _ShootingPercentagesRow extends StatelessWidget {
  const _ShootingPercentagesRow({required this.agg});
  final PlayerSeasonAggregate agg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PctCard(
            label: 'FG',
            pct: agg.fgPct,
            made: agg.twoPtMade + agg.threePtMade,
            attempted: agg.twoPtMade +
                agg.twoPtMissed +
                agg.threePtMade +
                agg.threePtMissed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PctCard(
            label: '3PT',
            pct: agg.threePtPct,
            made: agg.threePtMade,
            attempted: agg.threePtMade + agg.threePtMissed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PctCard(
            label: 'FT',
            pct: agg.ftPct,
            made: agg.ftMade,
            attempted: agg.ftMade + agg.ftMissed,
          ),
        ),
      ],
    );
  }
}

class _PctCard extends StatelessWidget {
  const _PctCard({
    required this.label,
    required this.pct,
    required this.made,
    required this.attempted,
  });

  final String label;
  final double? pct;
  final int made;
  final int attempted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              pct == null ? '—' : '${pct!.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$made / $attempted',
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


//---------------------Per-game points chart--------------------------------------


class _PerGameChartCard extends StatelessWidget {
  const _PerGameChartCard({required this.perGame});
  final List<GamePointsEntry> perGame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (perGame.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No games yet.')),
        ),
      );
    }

    final maxY =
        perGame.fold<int>(0, (m, e) => e.teamPoints > m ? e.teamPoints : m);
    final yMax =
        (maxY * 1.2).ceilToDouble().clamp(10, 999).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    final entry = perGame[group.x];
                    return BarTooltipItem(
                      'vs ${entry.opponent}\n${entry.teamPoints} pts',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
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
                      if (i < 0 || i >= perGame.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat.MMMd().format(perGame[i].date),
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
                for (var i = 0; i < perGame.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: perGame[i].teamPoints.toDouble(),
                        width: 18,
                        color: colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
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
}


//-----------------Game history list------------------------------------


class _GameHistoryCard extends StatelessWidget {
  const _GameHistoryCard({required this.perGame});
  final List<GamePointsEntry> perGame;

  @override
  Widget build(BuildContext context) {
    if (perGame.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No game history.')),
        ),
      );
    }

    // Show most recent first.
    final entries = [...perGame]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final e in entries) _HistoryRow(entry: e),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final GamePointsEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat.yMMMd().format(entry.date);

    final (chipLabel, chipBg, chipFg) = _resultStyle(entry, colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${entry.opponent}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              chipLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: chipFg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          // Player's points for this game
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.teamPoints}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'PTS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _resultStyle(
    GamePointsEntry e,
    ColorScheme cs,
  ) {
    switch (e.result) {
      case GameResult.win:
        return ('W', Colors.green.shade100, Colors.green.shade900);
      case GameResult.loss:
        return ('L', Colors.red.shade100, Colors.red.shade900);
      case null:
        return ('—', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}


//------------------ Misc-------------------------------------------------


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

class _PlayerGoneBlock extends StatelessWidget {
  const _PlayerGoneBlock();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Player not found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('They may have been removed from the roster.'),
          ],
        ),
      ),
    );
  }
}

enum _ExportAction { print, share }
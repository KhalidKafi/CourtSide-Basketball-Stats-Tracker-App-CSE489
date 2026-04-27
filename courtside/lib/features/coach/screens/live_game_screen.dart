import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../viewmodels/live_game_notifier.dart';
import '../viewmodels/team_notifiers.dart';

class LiveGameScreen extends ConsumerWidget {
  const LiveGameScreen({super.key, required this.gameId});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveGameNotifierProvider(gameId));
    final teamAsync = state.game == null
        ? const AsyncValue<dynamic>.loading()
        : ref.watch(teamByIdProvider(state.game!.teamId));

    // Until the streams have all loaded, render a loading skeleton.
    if (state.game == null || state.players.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final teamName = teamAsync is AsyncData
        ? (teamAsync.value as dynamic)?.name ?? 'Team'
        : 'Team';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldLeave = await _confirmLeave(context);
          if (shouldLeave && context.mounted) {
            context.go(AppRoutes.teamGames(state.game!.teamId));
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldLeave = await _confirmLeave(context);
              if (shouldLeave && context.mounted) {
                context.go(AppRoutes.teamGames(state.game!.teamId));
              }
            },
          ),
          title: Text(
            '$teamName  vs  ${state.game!.opponent}',
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Scoreboard(
                  teamName: teamName,
                  teamScore: state.teamScore,
                  opponentName: state.game!.opponent,
                  opponentScore: state.opponentScore,
                ),
                const SizedBox(height: 8),
                _OpponentScoreStrip(
                  enabled: !state.isLogging,
                  onBump: (delta) => ref
                      .read(liveGameNotifierProvider(gameId).notifier)
                      .bumpOpponentScore(delta),
                ),
                const SizedBox(height: 16),
                _PlayerSelectorRow(
                  players: state.players,
                  activePlayerId: state.activePlayerId,
                  pointsFor: state.pointsFor,
                  onSelect: (id) => ref
                      .read(liveGameNotifierProvider(gameId).notifier)
                      .selectPlayer(id),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _BottomPanel(
                    state: state,
                    onAction: (type) => ref
                        .read(liveGameNotifierProvider(gameId).notifier)
                        .logPlayerAction(type),
                    onUndo: () => ref
                        .read(liveGameNotifierProvider(gameId).notifier)
                        .undoLastAction(),
                    onEndGame: () => _openEndGameDialog(context, ref, state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the live game?'),
        content: const Text(
          'Your stats are saved. You can come back any time and resume from '
          'the games list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openEndGameDialog(
    BuildContext context,
    WidgetRef ref,
    LiveGameState state,
  ) async {
    if (state.game == null) return;

    final result = await showDialog<_EndGameResult>(
      context: context,
      builder: (_) => _EndGameDialog(
        teamScore: state.teamScore,
        opponentScoreLive: state.opponentScore,
      ),
    );

    if (result == null || !context.mounted) return;

    await ref.read(liveGameNotifierProvider(gameId).notifier).endGame(
          result: result.outcome,
          finalOpponentScore: result.finalOpponentScore,
        );

    if (!context.mounted) return;
    context.go(AppRoutes.gameSummary(gameId));
  }
}


// Scoreboard

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.teamName,
    required this.teamScore,
    required this.opponentName,
    required this.opponentScore,
  });

  final String teamName;
  final int teamScore;
  final String opponentName;
  final int opponentScore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: _ScoreSide(
                label: teamName,
                score: teamScore,
                isUs: true,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ':',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreSide(
                label: opponentName,
                score: opponentScore,
                isUs: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({
    required this.label,
    required this.score,
    required this.isUs,
  });

  final String label;
  final int score;
  final bool isUs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isUs ? colorScheme.primary : colorScheme.onSurface;
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}


// Opponent score strip — +1 / +2 / +3

class _OpponentScoreStrip extends StatelessWidget {
  const _OpponentScoreStrip({required this.enabled, required this.onBump});

  final bool enabled;
  final ValueChanged<int> onBump;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Opp:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 8),
        for (final delta in [1, 2, 3]) ...[
          OutlinedButton(
            onPressed: enabled ? () => onBump(delta) : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 36),
              padding: EdgeInsets.zero,
            ),
            child: Text('+$delta'),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}


// Player selector row

class _PlayerSelectorRow extends StatelessWidget {
  const _PlayerSelectorRow({
    required this.players,
    required this.activePlayerId,
    required this.pointsFor,
    required this.onSelect,
  });

  final List<Player> players;
  final int? activePlayerId;
  final int Function(int playerId) pointsFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = players[i];
          final selected = activePlayerId == p.id;
          return _PlayerChip(
            player: p,
            points: pointsFor(p.id),
            selected: selected,
            onTap: () => onSelect(p.id),
          );
        },
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.points,
    required this.selected,
    required this.onTap,
  });

  final Player player;
  final int points;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primary : colorScheme.surfaceContainer;
    final fg =
        selected ? colorScheme.onPrimary : colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.onPrimary.withValues(alpha: 0.2)
                      : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${player.jerseyNumber}',
                  style: TextStyle(
                    color: selected ? colorScheme.onPrimary : colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _shortName(player.name),
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$points pts',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "LeBron James" → "LeBron J."
  String _shortName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }
}


// Bottom panel — active player card + action grid

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.onAction,
    required this.onUndo,
    required this.onEndGame,
  });

  final LiveGameState state;
  final ValueChanged<PlayerActionType> onAction;
  final VoidCallback onUndo;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActivePlayerCard(state: state),
        const SizedBox(height: 12),
        Expanded(
          child: _ActionGrid(
            canLog: state.canLogAction,
            canUndo: state.canUndo,
            onAction: onAction,
            onUndo: onUndo,
            onEndGame: onEndGame,
          ),
        ),
      ],
    );
  }
}

class _ActivePlayerCard extends StatelessWidget {
  const _ActivePlayerCard({required this.state});
  final LiveGameState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = state.activePlayer;

    if (p == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap a player above to start logging actions.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final stat = state.statsByPlayerId[p.id];
    final pts = stat == null
        ? 0
        : stat.twoPtMade * 2 + stat.threePtMade * 3 + stat.ftMade;
    final fgMade = (stat?.twoPtMade ?? 0) + (stat?.threePtMade ?? 0);
    final fgAtt = fgMade +
        (stat?.twoPtMissed ?? 0) +
        (stat?.threePtMissed ?? 0);
    final ftMade = stat?.ftMade ?? 0;
    final ftAtt = ftMade + (stat?.ftMissed ?? 0);

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${p.jerseyNumber}',
                style: TextStyle(
                  color: colorScheme.primaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$pts PTS · $fgMade-$fgAtt FG · $ftMade-$ftAtt FT',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.85),
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

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.canLog,
    required this.canUndo,
    required this.onAction,
    required this.onUndo,
    required this.onEndGame,
  });

  final bool canLog;
  final bool canUndo;
  final ValueChanged<PlayerActionType> onAction;
  final VoidCallback onUndo;
  final VoidCallback onEndGame;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        _ActionButton(
          label: '+2 Made',
          color: Colors.green,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.twoPtMade),
        ),
        _ActionButton(
          label: '+2 Miss',
          color: Colors.red.shade300,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.twoPtMissed),
        ),
        _ActionButton(
          label: 'Undo',
          icon: Icons.undo,
          color: Theme.of(context).colorScheme.tertiary,
          enabled: canUndo,
          onTap: onUndo,
        ),
        _ActionButton(
          label: '+3 Made',
          color: Colors.green.shade700,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.threePtMade),
        ),
        _ActionButton(
          label: '+3 Miss',
          color: Colors.red.shade400,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.threePtMissed),
        ),
        _ActionButton(
          label: 'End Game',
          icon: Icons.flag,
          color: Theme.of(context).colorScheme.error,
          enabled: true,
          onTap: onEndGame,
        ),
        _ActionButton(
          label: 'FT Made',
          color: Colors.green.shade400,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.ftMade),
        ),
        _ActionButton(
          label: 'FT Miss',
          color: Colors.red.shade200,
          enabled: canLog,
          onTap: () => onAction(PlayerActionType.ftMissed),
        ),
        const SizedBox.shrink(), // empty 9th cell
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, color: Colors.white, size: 20),
              if (icon != null) const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// End Game dialog

class _EndGameResult {
  final GameResult outcome;
  final int finalOpponentScore;
  const _EndGameResult({required this.outcome, required this.finalOpponentScore});
}

class _EndGameDialog extends StatefulWidget {
  const _EndGameDialog({
    required this.teamScore,
    required this.opponentScoreLive,
  });

  final int teamScore;
  final int opponentScoreLive;

  @override
  State<_EndGameDialog> createState() => _EndGameDialogState();
}

class _EndGameDialogState extends State<_EndGameDialog> {
  late final TextEditingController _opponentCtrl;
  GameResult _result = GameResult.win;

  @override
  void initState() {
    super.initState();
    _opponentCtrl =
        TextEditingController(text: '${widget.opponentScoreLive}');
    _autoDetectResult();
  }

  void _autoDetectResult() {
    final opp = int.tryParse(_opponentCtrl.text) ?? 0;
    setState(() {
      _result = widget.teamScore >= opp ? GameResult.win : GameResult.loss;
    });
  }

  @override
  void dispose() {
    _opponentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End game?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your team: ${widget.teamScore} pts'),
          const SizedBox(height: 12),
          TextField(
            controller: _opponentCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Opponent final score',
            ),
            onChanged: (_) => _autoDetectResult(),
          ),
          const SizedBox(height: 16),
          Text(
            'Result',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          SegmentedButton<GameResult>(
            segments: const [
              ButtonSegment(
                value: GameResult.win,
                label: Text('Win'),
                icon: Icon(Icons.emoji_events_outlined),
              ),
              ButtonSegment(
                value: GameResult.loss,
                label: Text('Loss'),
                icon: Icon(Icons.remove_circle_outline),
              ),
            ],
            selected: {_result},
            onSelectionChanged: (s) => setState(() => _result = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final score = int.tryParse(_opponentCtrl.text) ?? 0;
            Navigator.pop(
              context,
              _EndGameResult(
                outcome: _result,
                finalOpponentScore: score,
              ),
            );
          },
          child: const Text('Finish Game'),
        ),
      ],
    );
  }
}
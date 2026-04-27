import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../models/game.dart';
import '../viewmodels/game_notifiers.dart';
import '../viewmodels/team_notifiers.dart';
import 'widgets/game_result_chip.dart';

/// Lists all games for a single team.
class GameListScreen extends ConsumerWidget {
  const GameListScreen({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final gamesAsync = ref.watch(gamesForTeamProvider(teamId));
    final inProgressAsync =
        ref.watch(inProgressGameForTeamProvider(teamId));

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
            loading: () => const Text('Games'),
            error: (_, __) => const Text('Games'),
            data: (team) => Text('${team?.name ?? "Team"}  ·  Games'),
          ),
        ),
        body: gamesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (games) {
            if (games.isEmpty) return const _EmptyState();
            return _GameList(games: games);
          },
        ),
        floatingActionButton: _BuildFab(
          teamId: teamId,
          inProgressAsync: inProgressAsync,
        ),
      ),
    );
  }
}


// FAB — adapts label depending on whether a live game is in progress

class _BuildFab extends StatelessWidget {
  const _BuildFab({
    required this.teamId,
    required this.inProgressAsync,
  });

  final int teamId;
  final AsyncValue<Game?> inProgressAsync;

  @override
  Widget build(BuildContext context) {
    return inProgressAsync.maybeWhen(
      data: (inProgress) {
        if (inProgress != null) {
          // There's a live game — show "Resume" instead.
          return FloatingActionButton.extended(
            onPressed: () =>
                context.go(AppRoutes.liveGame(inProgress.id)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume Live Game'),
          );
        }
        return FloatingActionButton.extended(
          onPressed: () => context.go(AppRoutes.newGame(teamId)),
          icon: const Icon(Icons.add),
          label: const Text('New Game'),
        );
      },
      orElse: () => FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.newGame(teamId)),
        icon: const Icon(Icons.add),
        label: const Text('New Game'),
      ),
    );
  }
}


// List body

class _GameList extends StatelessWidget {
  const _GameList({required this.games});
  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _GameCard(game: games[i]),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateText = DateFormat.yMMMd().format(game.date);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!game.isFinished) {
            context.go(AppRoutes.liveGame(game.id));
          } else {
            context.go(AppRoutes.gameSummary(game.id));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  game.homeAway == HomeAway.home
                      ? Icons.home_outlined
                      : Icons.flight_takeoff_outlined,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'vs ${game.opponent}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GameResultChip(game: game),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateText  ·  ${game.homeAway.displayName}'
                      '${game.isFinished ? "  ·  Opp ${game.opponentScore}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
            Icon(
              Icons.sports_basketball_outlined,
              size: 72,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No games yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "New Game" to set up your first game.',
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../models/game.dart';
import '../../../models/recent_game.dart';
import '../../../models/team.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../viewmodels/game_notifiers.dart';
import '../viewmodels/team_notifiers.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    final teamsAsync = ref.watch(teamsForCoachProvider(user.id));
    final totalPlayersAsync = ref.watch(totalPlayersForCoachProvider(user.id));
    final recentGamesAsync = ref.watch(recentGamesForCoachProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(userName: user.name, userEmail: user.email),
              const SizedBox(height: 20),
              _QuickStatsRow(
                teamsAsync: teamsAsync,
                totalPlayersAsync: totalPlayersAsync,
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Recent Teams',
                actionLabel: 'See all',
                onAction: () => context.go(AppRoutes.coachTeams),
              ),
              const SizedBox(height: 12),
              _RecentTeamsList(teamsAsync: teamsAsync),
              const SizedBox(height: 20),
              const _SectionHeader(
                title: 'Recent Games',
                actionLabel: null,
                onAction: null,
              ),
              const SizedBox(height: 12),
              _RecentGamesList(gamesAsync: recentGamesAsync),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.coachTeams),
                icon: const Icon(Icons.groups),
                label: const Text('Manage Teams'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.userName, required this.userEmail});

  final String userName;
  final String userEmail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.sports,
                size: 32,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    userEmail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
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

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.teamsAsync,
    required this.totalPlayersAsync,
  });

  final AsyncValue<List<Team>> teamsAsync;
  final AsyncValue<int> totalPlayersAsync;

  @override
  Widget build(BuildContext context) {
    final teamCount = teamsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final playerCount = totalPlayersAsync.maybeWhen(
      data: (n) => n,
      orElse: () => 0,
    );
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Teams',
            value: '$teamCount',
            icon: Icons.groups_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Players',
            value: '$playerCount',
            icon: Icons.person_outline,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _RecentTeamsList extends StatelessWidget {
  const _RecentTeamsList({required this.teamsAsync});
  final AsyncValue<List<Team>> teamsAsync;

  @override
  Widget build(BuildContext context) {
    return teamsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (teams) {
        if (teams.isEmpty) return const _NoTeamsCard();
        // Show only top 3 most recent (teams are already sorted by
        // createdAt DESC by the repository query).
        final recent = teams.take(3).toList();
        return Column(
          children: [
            for (final t in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MiniTeamTile(team: t),
              ),
          ],
        );
      },
    );
  }
}

class _MiniTeamTile extends StatelessWidget {
  const _MiniTeamTile({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(AppRoutes.coachTeamDetail(team.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.groups,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${team.season}  ·  ${team.homeCourt}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoTeamsCard extends StatelessWidget {
  const _NoTeamsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.groups_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No teams yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Manage Teams" below to create one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentGamesList extends StatelessWidget {
  const _RecentGamesList({required this.gamesAsync});
  final AsyncValue<List<RecentGame>> gamesAsync;

  @override
  Widget build(BuildContext context) {
    return gamesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (games) {
        if (games.isEmpty) return const _NoGamesCard();
        final recent = games.take(3).toList();
        return Column(
          children: [
            for (final rg in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MiniGameTile(recentGame: rg),
              ),
          ],
        );
      },
    );
  }
}

class _MiniGameTile extends StatelessWidget {
  const _MiniGameTile({required this.recentGame});
  final RecentGame recentGame;

  @override
  Widget build(BuildContext context) {
    final game = recentGame.game;
    final colorScheme = Theme.of(context).colorScheme;
    final (chipLabel, chipBg, chipFg) = _resultStyle(game, colorScheme);

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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  game.homeAway == HomeAway.home
                      ? Icons.home_outlined
                      : Icons.flight_takeoff_outlined,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recentGame.teamName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'vs ${game.opponent}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(game),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chipLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: chipFg,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(Game g) {
    final dateStr =
        '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}-${g.date.day.toString().padLeft(2, '0')}';
    if (g.isFinished) {
      return '$dateStr  ·  Opp ${g.opponentScore}';
    }
    return '$dateStr  ·  In progress';
  }

  (String, Color, Color) _resultStyle(Game g, ColorScheme cs) {
    if (!g.isFinished) {
      return ('LIVE', cs.primary, cs.onPrimary);
    }
    switch (g.result) {
      case GameResult.win:
        return ('WIN', Colors.green.shade100, Colors.green.shade900);
      case GameResult.loss:
        return ('LOSS', Colors.red.shade100, Colors.red.shade900);
      case null:
        return ('—', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}

class _NoGamesCard extends StatelessWidget {
  const _NoGamesCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.sports_basketball_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No games yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a team to set up your first game.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
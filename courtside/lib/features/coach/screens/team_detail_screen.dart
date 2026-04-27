import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../models/player.dart';
import '../../../models/team.dart';
import '../viewmodels/team_notifiers.dart';
import 'player_form_sheet.dart';
import 'team_form_sheet.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamByIdProvider(teamId));
    final playersAsync = ref.watch(playersForTeamProvider(teamId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.coachTeams);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.coachTeams),
          ),
          title: teamAsync.when(
            loading: () => const Text('Loading…'),
            error: (_, __) => const Text('Team'),
            data: (team) => Text(team?.name ?? 'Team'),
          ),
          actions: [
            PopupMenuButton<_TeamMenuAction>(
              onSelected: (action) => _handleMenuAction(
                  context,
                  ref,
                  action,
                  teamAsync.valueOrNull,
                ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _TeamMenuAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Edit team'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _TeamMenuAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete team', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: teamAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorBlock(message: err.toString()),
          data: (team) {
            if (team == null) return const _TeamGoneBlock();
            return _TeamDetailBody(team: team, playersAsync: playersAsync);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddPlayer(context),
          icon: const Icon(Icons.person_add),
          label: const Text('Add Player'),
        ),
      ),
    );
  }

  // ─── Menu actions ───────────────────────────────────────────────────────

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    _TeamMenuAction action,
    Team? currentTeam,
  ) async {
    switch (action) {
      case _TeamMenuAction.edit:
        if (currentTeam != null) _openEditTeam(context, ref, currentTeam);
        break;
      case _TeamMenuAction.delete:
        await _confirmAndDelete(context, ref);
        break;
    }
  }

  Future<void> _confirmAndDelete(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this team?'),
        content: const Text(
          'This will permanently delete the team along with all its '
          'players, games, and stats. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final success =
        await ref.read(teamActionsProvider.notifier).deleteTeam(teamId);

    if (!context.mounted) return;
    if (success) {
      // Team is gone — bounce back to the list.
      context.go(AppRoutes.coachTeams);
    } else {
      final err =
          ref.read(teamActionsProvider.notifier).lastError ?? 'Delete failed.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // ─── Placeholders wired up in Steps before in 8 & 9 ───────────────────────────────

  void _openEditTeam(BuildContext context, WidgetRef ref, Team team) {
    TeamFormSheet.show(
      context,
      coachId: team.coachId,
      existingTeam: team,
    );
  }

  void _openAddPlayer(BuildContext context) {
    PlayerFormSheet.show(context, teamId: teamId);
  }
}

enum _TeamMenuAction { edit, delete }

// ──────────────────────────────────────────────────────────────────────────
// Sub-widgets — private to this file
// ──────────────────────────────────────────────────────────────────────────

class _TeamDetailBody extends StatelessWidget {
  const _TeamDetailBody({required this.team, required this.playersAsync});

  final Team team;
  final AsyncValue<List<Player>> playersAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _TeamInfoCard(team: team),
        const SizedBox(height: 16),
        _GamesShortcut(team: team),
        const SizedBox(height: 24),
        _RosterHeader(playersAsync: playersAsync),
        const SizedBox(height: 12),
        _RosterList(playersAsync: playersAsync),
      ],
    );
  }
}

class _TeamInfoCard extends StatelessWidget {
  const _TeamInfoCard({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.groups,
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
                        team.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team.homeCourt,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Season',
              value: team.season,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({required this.playersAsync});
  final AsyncValue<List<Player>> playersAsync;

  @override
  Widget build(BuildContext context) {
    final count = playersAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    return Row(
      children: [
        Text(
          'Roster',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.playersAsync});
  final AsyncValue<List<Player>> playersAsync;

  @override
  Widget build(BuildContext context) {
    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _ErrorBlock(message: err.toString()),
      data: (players) {
        if (players.isEmpty) return const _NoPlayersBlock();
        return Column(
          children: [
            for (final p in players) _PlayerCard(player: p),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => PlayerFormSheet.show(
            context,
            teamId: player.teamId,
            existingPlayer: player,
          ),
          onLongPress: () => _showPlayerActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _JerseyBadge(number: player.jerseyNumber),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        player.position.displayName,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
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
      ),
    );
  }

  void _showPlayerActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit player'),
              onTap: () {
                Navigator.pop(ctx);
                PlayerFormSheet.show(
                  context,
                  teamId: player.teamId,
                  existingPlayer: player,
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove from team',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${player.name}?'),
        content: const Text(
          'This will remove the player from the roster. Any game stats '
          'already recorded for this player will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final ok = await ref
        .read(playerActionsProvider.notifier)
        .deletePlayer(player.id);

    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove player.')),
      );
    }
  }
}

class _JerseyBadge extends StatelessWidget {
  const _JerseyBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _NoPlayersBlock extends StatelessWidget {
  const _NoPlayersBlock();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No players yet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add Player" to build your roster.',
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

class _TeamGoneBlock extends StatelessWidget {
  const _TeamGoneBlock();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 48),
            const SizedBox(height: 12),
            Text(
              'Team not found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('It may have been deleted.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.coachTeams),
              child: const Text('Back to teams'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _GamesShortcut extends StatelessWidget {
  const _GamesShortcut({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(AppRoutes.teamGames(team.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.tertiaryContainer,
                child: Icon(
                  Icons.sports_basketball_outlined,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Games',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View, create, and record live games',
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
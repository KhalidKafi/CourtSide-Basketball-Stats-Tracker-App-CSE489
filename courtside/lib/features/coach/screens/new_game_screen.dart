import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../models/game.dart';
import '../../../models/player.dart';
import '../../../models/team.dart';
import '../viewmodels/game_notifiers.dart';
import '../viewmodels/team_notifiers.dart';

/// Form for creating a new game. Reads the team's players to pre-initialize
/// stat rows, validates the team has at least one player before allowing
/// submission, and navigates to the live game screen on success.
class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key, required this.teamId});

  final int teamId;

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opponentCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  HomeAway _homeAway = HomeAway.home;

  @override
  void dispose() {
    _opponentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Allow up to 1 year past (recording an old game) and 1 year future
      // (scheduling). Reasonable bounds, not arbitrary.
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit(List<Player> players) async {
    if (!_formKey.currentState!.validate()) return;
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one player to the team before starting a game.',
          ),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final newId =
        await ref.read(gameActionsProvider.notifier).createGame(
              teamId: widget.teamId,
              opponent: _opponentCtrl.text,
              date: _date,
              homeAway: _homeAway,
              playerIds: players.map((p) => p.id).toList(),
            );

    if (!mounted) return;

    if (newId != null) {
      context.go(AppRoutes.liveGame(newId));
    } else {
      final err = ref.read(gameActionsProvider.notifier).lastError ??
          'Could not create game.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamByIdProvider(widget.teamId));
    final playersAsync = ref.watch(playersForTeamProvider(widget.teamId));
    final actions = ref.watch(gameActionsProvider);
    final isLoading = actions.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.teamGames(widget.teamId));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: isLoading
                ? null
                : () => context.go(AppRoutes.teamGames(widget.teamId)),
          ),
          title: const Text('New Game'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Team header
                  teamAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (team) => team == null
                        ? const SizedBox.shrink()
                        : _TeamHeader(team: team),
                  ),
                  const SizedBox(height: 20),

                  // Players guard
                  playersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (players) => players.isEmpty
                        ? _NoPlayersWarning(teamId: widget.teamId)
                        : const SizedBox.shrink(),
                  ),

                  // Opponent
                  TextFormField(
                    controller: _opponentCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Opponent team name',
                      hintText: 'e.g. Dhaka Wildcats',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) {
                        return 'Opponent name is required';
                      }
                      if (value.length < 2) {
                        return 'Must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date picker (read-only field — taps open the picker)
                  InkWell(
                    onTap: isLoading ? null : _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        DateFormat.yMMMMd().format(_date),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Home/Away segmented control
                  Text(
                    'Location',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<HomeAway>(
                    segments: const [
                      ButtonSegment(
                        value: HomeAway.home,
                        label: Text('Home'),
                        icon: Icon(Icons.home_outlined),
                      ),
                      ButtonSegment(
                        value: HomeAway.away,
                        label: Text('Away'),
                        icon: Icon(Icons.flight_takeoff_outlined),
                      ),
                    ],
                    selected: {_homeAway},
                    onSelectionChanged: isLoading
                        ? null
                        : (selection) {
                            setState(() => _homeAway = selection.first);
                          },
                  ),
                  const SizedBox(height: 32),

                  // Submit button — needs the player list to enable/disable
                  playersAsync.when(
                    loading: () => const FilledButton(
                      onPressed: null,
                      child: Text('Loading...'),
                    ),
                    error: (_, __) => const FilledButton(
                      onPressed: null,
                      child: Text('Could not load players'),
                    ),
                    data: (players) => FilledButton.icon(
                      onPressed: (isLoading || players.isEmpty)
                          ? null
                          : () => _submit(players),
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        isLoading ? 'Starting...' : 'Start Live Game',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Sub-widgets

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.groups,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                team.season,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoPlayersWarning extends StatelessWidget {
  const _NoPlayersWarning({required this.teamId});
  final int teamId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No players on this team',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add at least one player before you can record a game.',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go(
                        AppRoutes.coachTeamDetail(teamId),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      child: const Text('Go to roster →'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
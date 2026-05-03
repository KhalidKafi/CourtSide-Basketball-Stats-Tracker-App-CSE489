import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../../coach/viewmodels/team_notifiers.dart';
import '../viewmodels/admin_notifiers.dart';

class AdminCoachDetailScreen extends ConsumerWidget {
  const AdminCoachDetailScreen({super.key, required this.coachId});

  final int coachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(coachByIdProvider(coachId));
    final teamsAsync = ref.watch(teamsForCoachProvider(coachId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminCoaches);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.adminCoaches),
          ),
          title: coachAsync.when(
            loading: () => const Text('Coach'),
            error: (_, __) => const Text('Coach'),
            data: (c) => Text(c?.name ?? 'Coach'),
          ),
        ),
        body: coachAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (coach) {
            if (coach == null) {
              return const Center(child: Text('Coach not found.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CoachInfoCard(coach: coach),
                  const SizedBox(height: 16),
                  _DisableCoachCard(coachId: coachId),
                  const SizedBox(height: 24),
                  Text(
                    'Teams',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  teamsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (teams) {
                      if (teams.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'This coach has no teams.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final t in teams)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.groups),
                                title: Text(t.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(t.season),
                                trailing: IconButton(
                                  icon: const Icon(Icons.flag_outlined),
                                  tooltip: 'Flag this team',
                                  onPressed: () => _flagTeam(
                                      context, ref, t.id, t.name),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _flagTeam(
    BuildContext context,
    WidgetRef ref,
    int teamId,
    String teamName,
  ) async {
    final reason = await _askFlagReason(
      context,
      title: 'Flag team "$teamName"?',
      description:
          'Super Admin will review this flag and decide whether to delete the team or dismiss the report.',
    );
    if (reason == null || !context.mounted) return;

    final adminId = ref.read(authNotifierProvider).user?.id;
    if (adminId == null) return;

    final ok = await ref.read(adminActionsProvider.notifier).flagTeam(
          teamId: teamId,
          adminId: adminId,
          reason: reason,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Flag submitted to Super Admin.'
            : 'Could not submit flag.'),
      ),
    );
  }
}

class _CoachInfoCard extends StatelessWidget {
  const _CoachInfoCard({required this.coach});
  final dynamic coach; // AppUser

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                coach.name[0].toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coach.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(coach.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisableCoachCard extends ConsumerWidget {
  const _DisableCoachCard({required this.coachId});
  final int coachId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(coachUserRowProvider(coachId));
    final colorScheme = Theme.of(context).colorScheme;

    return userAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const SizedBox.shrink();
        }
        final disabled = user.isDisabled;
        return Card(
          color: disabled
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHighest,
          child: SwitchListTile(
            value: !disabled,
            title: Text(
              disabled ? 'Account disabled' : 'Account active',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              disabled
                  ? 'This coach cannot log in until re-enabled.'
                  : 'Toggle off to prevent this coach from logging in.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onChanged: (newValue) async {
              final shouldDisable = !newValue;
              final ok = await ref
                  .read(adminActionsProvider.notifier)
                  .setCoachDisabled(coachId, shouldDisable);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? (shouldDisable
                            ? 'Coach disabled.'
                            : 'Coach re-enabled.')
                        : 'Could not update coach.',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Future<String?> _askFlagReason(
  BuildContext context, {
  required String title,
  required String description,
}) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _FlagReasonDialog(
      title: title,
      description: description,
    ),
  );
}

class _FlagReasonDialog extends StatefulWidget {
  const _FlagReasonDialog({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  State<_FlagReasonDialog> createState() => _FlagReasonDialogState();
}

class _FlagReasonDialogState extends State<_FlagReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Briefly explain the issue',
            ),
            maxLines: 3,
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
            final text = _ctrl.text.trim();
            if (text.length < 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please write a reason (at least 5 characters).',
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, text);
          },
          child: const Text('Submit Flag'),
        ),
      ],
    );
  }
}
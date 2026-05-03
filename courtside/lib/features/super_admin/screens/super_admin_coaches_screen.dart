import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../models/app_user.dart';
import '../../admin/viewmodels/admin_notifiers.dart';
import '../viewmodels/super_admin_notifiers.dart';

class SuperAdminCoachesScreen extends ConsumerWidget {
  const SuperAdminCoachesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(allCoachesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.superAdminHome);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.superAdminHome),
          ),
          title: const Text('Coaches'),
        ),
        body: coachesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (coaches) {
            if (coaches.isEmpty) {
              return const Center(child: Text('No coaches.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: coaches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CoachCard(coach: coaches[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CoachCard extends ConsumerWidget {
  const _CoachCard({required this.coach});
  final AppUser coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(coach.name[0].toUpperCase()),
        ),
        title: Text(coach.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(coach.email),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete coach',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${coach.name}?'),
        content: const Text(
          'This will permanently delete the coach and ALL their teams, players, games, and stats. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(superAdminActionsProvider.notifier)
        .deleteCoach(coach.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Coach deleted.' : 'Could not delete.')),
    );
  }
}
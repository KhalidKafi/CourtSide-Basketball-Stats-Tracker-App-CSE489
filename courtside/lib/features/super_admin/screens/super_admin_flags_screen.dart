import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../repositories/super_admin_repository.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../viewmodels/super_admin_notifiers.dart';

class SuperAdminFlagsScreen extends ConsumerWidget {
  const SuperAdminFlagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(unresolvedFlagsProvider);

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
          title: const Text('Flag Queue'),
        ),
        body: flagsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (flags) {
            if (flags.isEmpty) {
              return const _EmptyFlags();
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: flags.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _FlagCard(flag: flags[i]),
            );
          },
        ),
      ),
    );
  }
}

class _FlagCard extends ConsumerWidget {
  const _FlagCard({required this.flag});
  final FlagItem flag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.yMMMd().add_jm().format(flag.flaggedAt);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    flag.targetType.toUpperCase(),
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('ID #${flag.targetId}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              flag.reason,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Flagged by ${flag.flaggedByName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _dismiss(context, ref),
                    icon: const Icon(Icons.close),
                    label: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _deleteTarget(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Delete ${flag.targetType}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final superAdminId = ref.read(authNotifierProvider).user?.id;
    if (superAdminId == null) return;
    final ok = await ref
        .read(superAdminActionsProvider.notifier)
        .dismissFlag(flagId: flag.id, superAdminId: superAdminId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Flag dismissed.' : 'Could not dismiss.')),
    );
  }

  Future<void> _deleteTarget(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this ${flag.targetType}?'),
        content: Text(
          'This permanently deletes the ${flag.targetType} and all its associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final superAdminId = ref.read(authNotifierProvider).user?.id;
    if (superAdminId == null) return;

    final ok = await ref
        .read(superAdminActionsProvider.notifier)
        .deleteFlagTarget(flag: flag, superAdminId: superAdminId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '${flag.targetType} deleted.' : 'Could not delete.',
        ),
      ),
    );
  }
}

class _EmptyFlags extends StatelessWidget {
  const _EmptyFlags();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.shade400),
            const SizedBox(height: 12),
            const Text('All clear.'),
            const SizedBox(height: 4),
            const Text('No unresolved flags right now.'),
          ],
        ),
      ),
    );
  }
}
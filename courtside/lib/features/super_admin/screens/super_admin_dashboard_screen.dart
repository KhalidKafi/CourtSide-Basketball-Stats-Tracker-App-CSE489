import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../../admin/viewmodels/admin_notifiers.dart';
import '../viewmodels/super_admin_notifiers.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final countsAsync = ref.watch(systemCountsProvider);
    final flagsAsync = ref.watch(unresolvedFlagsProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

   
   // Main dashboard layout   
   
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(name: user.name),
              const SizedBox(height: 20),
              const _SectionTitle('System Overview'),
              const SizedBox(height: 12),
              _CountsGrid(countsAsync: countsAsync),
              const SizedBox(height: 24),
              const _SectionTitle('Quick Actions'),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.go(AppRoutes.superAdminAdmins),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, color: Colors.indigo, size: 28),
                              SizedBox(height: 6),
                              Text('Admins', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.go(AppRoutes.superAdminCoaches),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outlined, color: Colors.teal, size: 28),
                              SizedBox(height: 6),
                              Text('Coaches', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.go(AppRoutes.superAdminFlags),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag_outlined, color: Colors.red, size: 28),
                              SizedBox(height: 6),
                              Text('Flags', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _FlagQueuePreview(flagsAsync: flagsAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.deepPurple.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.shield, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, $name',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                  const Text('Super Admin'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountsGrid extends StatelessWidget {
  const _CountsGrid({required this.countsAsync});
  final AsyncValue<dynamic> countsAsync;

  @override
  Widget build(BuildContext context) {
    return countsAsync.when(
      loading: () => const SizedBox(
        height: 154,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (c) => SizedBox(
        height: 154,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CountTile(icon: Icons.person_outlined, label: 'Coaches', value: '${c.coaches}', color: Colors.blue)),
                  const SizedBox(width: 10),
                  Expanded(child: _CountTile(icon: Icons.groups_outlined, label: 'Teams', value: '${c.teams}', color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CountTile(icon: Icons.sports_basketball_outlined, label: 'Players', value: '${c.players}', color: Colors.deepOrange)),
                  const SizedBox(width: 10),
                  Expanded(child: _CountTile(icon: Icons.event_outlined, label: 'Games', value: '${c.games}', color: Colors.purple)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FlagQueuePreview extends StatelessWidget {
  const _FlagQueuePreview({required this.flagsAsync});
  final AsyncValue<dynamic> flagsAsync;

  @override
  Widget build(BuildContext context) {
    return flagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('Error: $e'),
      data: (flags) {
        if ((flags as List).isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('No unresolved flags.')),
                ],
              ),
            ),
          );
        }
        return Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${flags.length} unresolved flag${flags.length == 1 ? "" : "s"}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Tap to review.'),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () => context.go(AppRoutes.superAdminFlags),
                  child: const Text('Review'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}
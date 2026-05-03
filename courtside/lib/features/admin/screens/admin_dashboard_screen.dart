import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/viewmodels/auth_notifier.dart';
import '../viewmodels/admin_notifiers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final countsAsync = ref.watch(systemCountsProvider);
    final coachesAsync = ref.watch(allCoachesProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(name: user.name, email: user.email),
              const SizedBox(height: 20),
              _SectionTitle('System Overview'),
              const SizedBox(height: 12),
              _CountsGrid(countsAsync: countsAsync),
              const SizedBox(height: 24),
              _SectionTitle('Coaches'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.adminCoaches),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Browse all coaches'),
              ),
              const SizedBox(height: 16),
              _RecentCoachesList(coachesAsync: coachesAsync),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.onPrimaryContainer,
              child: Icon(Icons.shield_outlined,
                  color: colorScheme.primaryContainer),
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
                                color: colorScheme.onPrimaryContainer,
                              )),
                  Text(email,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.85),
                              )),
                  Text('Admin',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.7),
                              )),
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
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
      ),
      data: (c) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _CountTile(
              icon: Icons.person_outlined,
              label: 'Coaches',
              value: '${c.coaches}',
              color: Colors.blue,
            ),
            _CountTile(
              icon: Icons.groups_outlined,
              label: 'Teams',
              value: '${c.teams}',
              color: Colors.green,
            ),
            _CountTile(
              icon: Icons.sports_basketball_outlined,
              label: 'Players',
              value: '${c.players}',
              color: Colors.deepOrange,
            ),
            _CountTile(
              icon: Icons.event_outlined,
              label: 'Games',
              value: '${c.games}',
              color: Colors.purple,
            ),
          ],
        );
      },
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      )),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCoachesList extends StatelessWidget {
  const _RecentCoachesList({required this.coachesAsync});
  final AsyncValue<dynamic> coachesAsync;

  @override
  Widget build(BuildContext context) {
    return coachesAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (coaches) {
        if (coaches.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No coaches signed up yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final preview = (coaches as List).take(3).toList();
        return Column(
          children: [
            for (final c in preview)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(c.name[0])),
                  title: Text(c.name),
                  subtitle: Text(c.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.adminCoaches, // simple path; we'll route below
                  ),
                ),
              ),
          ],
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
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
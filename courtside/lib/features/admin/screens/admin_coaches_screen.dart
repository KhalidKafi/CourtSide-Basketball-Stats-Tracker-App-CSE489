import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../models/app_user.dart';
import '../viewmodels/admin_notifiers.dart';

class AdminCoachesScreen extends ConsumerStatefulWidget {
  const AdminCoachesScreen({super.key});

  @override
  ConsumerState<AdminCoachesScreen> createState() =>
      _AdminCoachesScreenState();
}

class _AdminCoachesScreenState extends ConsumerState<AdminCoachesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coachesAsync = ref.watch(allCoachesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminHome);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.adminHome),
          ),
          title: const Text('Coaches'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search coaches...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: coachesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (coaches) {
                  final filtered = _filter(coaches);
                  if (filtered.isEmpty) {
                    return _EmptyState(query: _query);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _CoachCard(coach: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppUser> _filter(List<AppUser> coaches) {
    if (_query.isEmpty) return coaches;
    final q = _query.toLowerCase();
    return coaches
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList();
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach});
  final AppUser coach;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(coach.name[0].toUpperCase())),
        title: Text(coach.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(coach.email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.adminCoachDetail(coach.id)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              query.isEmpty ? Icons.person_off : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No coaches in the system yet.'
                  : 'No coaches match "$query".',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
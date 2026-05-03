import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/password_generator.dart';
import '../../../models/app_user.dart';
import '../viewmodels/super_admin_notifiers.dart';

class SuperAdminAdminsScreen extends ConsumerWidget {
  const SuperAdminAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(allAdminsProvider);

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
          title: const Text('Admins'),
        ),
        body: adminsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (admins) {
            if (admins.isEmpty) {
              return const _EmptyState();
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: admins.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AdminCard(admin: admins[i]),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateAdminSheet(context, ref),
          icon: const Icon(Icons.person_add),
          label: const Text('New Admin'),
        ),
      ),
    );
  }

  Future<void> _openCreateAdminSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateAdminSheet(),
    );
  }
}

//==============Admin card with action menu========================
class _AdminCard extends ConsumerWidget {
  const _AdminCard({required this.admin});
  final AppUser admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            admin.name[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(admin.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(admin.email),
        trailing: PopupMenuButton<String>(
          onSelected: (action) =>
              _handleAction(context, ref, action),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.lock_reset),
                  SizedBox(width: 8),
                  Text('Reset password'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete admin', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'reset':
        await _resetPassword(context, ref);
        break;
      case 'delete':
        await _deleteAdmin(context, ref);
        break;
    }
  }

  Future<void> _resetPassword(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final newPwd = await _showPasswordPrompt(
      context,
      title: 'Reset password for ${admin.name}',
    );
    if (newPwd == null || !context.mounted) return;
    final ok = await ref
        .read(superAdminActionsProvider.notifier)
        .resetPassword(admin.id, newPwd);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Password reset. Share with admin: $newPwd'
              : 'Could not reset password.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _deleteAdmin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${admin.name}?'),
        content: const Text(
          'This permanently removes the admin account. Their flag history is preserved.',
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
    final ok = await ref
        .read(superAdminActionsProvider.notifier)
        .deleteAdmin(admin.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Admin deleted.' : 'Could not delete.')),
    );
  }
}


//==============Create-admin bottom sheet========================


class _CreateAdminSheet extends ConsumerStatefulWidget {
  const _CreateAdminSheet();

  @override
  ConsumerState<_CreateAdminSheet> createState() =>
      _CreateAdminSheetState();
}

class _CreateAdminSheetState extends ConsumerState<_CreateAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final pwd = PasswordGenerator.generate();
    setState(() => _passwordCtrl.text = pwd);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await ref
        .read(superAdminActionsProvider.notifier)
        .createAdmin(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;
    if (result.ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Admin created. Password: ${_passwordCtrl.text}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not create admin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(superAdminActionsProvider);
    final isLoading = actions.isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New Admin',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  if (!value.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: TextButton(
                    onPressed: _generatePassword,
                    child: const Text('Generate'),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: Text(isLoading ? 'Creating...' : 'Create Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


//=================Helpers===========================

Future<String?> _showPasswordPrompt(
  BuildContext context, {
  required String title,
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'New password',
              suffixIcon: TextButton(
                onPressed: () {
                  ctrl.text = PasswordGenerator.generate();
                },
                child: const Text('Generate'),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = ctrl.text;
            if (v.length < 6) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                    content: Text('At least 6 characters.')),
              );
              return;
            }
            Navigator.pop(ctx, v);
          },
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text('No admins yet.'),
            const SizedBox(height: 8),
            const Text('Tap "New Admin" to create one.'),
          ],
        ),
      ),
    );
  }
}
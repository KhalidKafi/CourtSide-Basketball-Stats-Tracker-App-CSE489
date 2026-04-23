import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/team.dart';
import '../viewmodels/team_notifiers.dart';

/// Bottom-sheet form for creating or editing a team.
///
/// - Pass `existingTeam: null` (or omit) to open in CREATE mode.
/// - Pass an existing team to open in EDIT mode — fields are pre-filled.
///
/// Returns `true` via Navigator.pop when the save succeeds, `null` if the
/// user dismisses. Callers don't need to use the return value — the
/// streaming provider auto-refreshes whichever list is watching.
class TeamFormSheet extends ConsumerStatefulWidget {
  const TeamFormSheet({
    super.key,
    required this.coachId,
    this.existingTeam,
  });

  final int coachId;
  final Team? existingTeam;

  bool get isEditing => existingTeam != null;

  /// Convenience — the caller doesn't have to know about `showModalBottomSheet`
  /// config; we set sensible defaults here.
  static Future<bool?> show(
    BuildContext context, {
    required int coachId,
    Team? existingTeam,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // lets the sheet grow with keyboard
      showDragHandle: true,
      builder: (_) => TeamFormSheet(
        coachId: coachId,
        existingTeam: existingTeam,
      ),
    );
  }

  @override
  ConsumerState<TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends ConsumerState<TeamFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _seasonCtrl;
  late final TextEditingController _homeCourtCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTeam;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _seasonCtrl = TextEditingController(text: t?.season ?? '');
    _homeCourtCtrl = TextEditingController(text: t?.homeCourt ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _seasonCtrl.dispose();
    _homeCourtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(teamActionsProvider.notifier);
    final bool success;

    if (widget.isEditing) {
      success = await notifier.updateTeam(
        id: widget.existingTeam!.id,
        name: _nameCtrl.text,
        season: _seasonCtrl.text,
        homeCourt: _homeCourtCtrl.text,
      );
    } else {
      success = await notifier.createTeam(
        coachId: widget.coachId,
        name: _nameCtrl.text,
        season: _seasonCtrl.text,
        homeCourt: _homeCourtCtrl.text,
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      final err = notifier.lastError ?? 'Something went wrong.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(teamActionsProvider);
    final isLoading = actions.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    // Padding.bottom with keyboard-inset makes the sheet slide up when
    // the keyboard appears instead of the form being hidden behind it.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Edit Team' : 'New Team',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isEditing
                    ? 'Update the team\'s details.'
                    : 'Give your team a name, season, and home court.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Team name',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Team name is required';
                  if (value.length < 2) {
                    return 'Must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _seasonCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  hintText: 'e.g. 2026 Spring',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Season is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _homeCourtCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Home court',
                  hintText: 'e.g. BRAC University Gym',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Home court is required';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(widget.isEditing ? 'Save Changes' : 'Create Team'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/player.dart';
import '../viewmodels/team_notifiers.dart';

/// Bottom-sheet form for creating or editing a player.
///
/// - Pass `existingPlayer: null` (default) for CREATE mode.
/// - Pass an existing player for EDIT mode — fields pre-filled.
class PlayerFormSheet extends ConsumerStatefulWidget {
  const PlayerFormSheet({
    super.key,
    required this.teamId,
    this.existingPlayer,
  });

  final int teamId;
  final Player? existingPlayer;

  bool get isEditing => existingPlayer != null;

  static Future<bool?> show(
    BuildContext context, {
    required int teamId,
    Player? existingPlayer,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlayerFormSheet(
        teamId: teamId,
        existingPlayer: existingPlayer,
      ),
    );
  }

  @override
  ConsumerState<PlayerFormSheet> createState() => _PlayerFormSheetState();
}

class _PlayerFormSheetState extends ConsumerState<PlayerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _jerseyCtrl;

  /// The currently-selected position in the dropdown.
  /// Nullable only in create mode before the user picks; we default it
  /// to Point Guard for convenience.
  PlayerPosition _position = PlayerPosition.pointGuard;

  /// Holds the "jersey taken" error message when the repository returns
  /// one. Cleared when the user edits either field, so the error
  /// disappears as they correct it.
  String? _jerseyError;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlayer;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _jerseyCtrl =
        TextEditingController(text: p == null ? '' : '${p.jerseyNumber}');
    _position = p?.position ?? PlayerPosition.pointGuard;

    // Clear the jersey-taken error as soon as the user edits the number,
    // so they can see the fix take effect before resubmitting.
    _jerseyCtrl.addListener(() {
      if (_jerseyError != null) setState(() => _jerseyError = null);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jerseyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _jerseyError = null);

    final jersey = int.parse(_jerseyCtrl.text);
    final notifier = ref.read(playerActionsProvider.notifier);

    final result = widget.isEditing
        ? await notifier.updatePlayer(
            id: widget.existingPlayer!.id,
            teamId: widget.teamId,
            name: _nameCtrl.text,
            jerseyNumber: jersey,
            position: _position,
          )
        : await notifier.createPlayer(
            teamId: widget.teamId,
            name: _nameCtrl.text,
            jerseyNumber: jersey,
            position: _position,
          );

    if (!mounted) return;

    if (result.ok) {
      Navigator.pop(context, true);
      return;
    }

    final err = result.error ?? 'Something went wrong.';
    // If it's a jersey-collision, show inline. Otherwise SnackBar.
    if (err.toLowerCase().contains('jersey')) {
      setState(() => _jerseyError = err);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(playerActionsProvider);
    final isLoading = actions.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

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
                widget.isEditing ? 'Edit Player' : 'Add Player',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isEditing
                    ? 'Update this player\'s details.'
                    : 'Enter the player\'s name, jersey number, and position.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Name is required';
                  if (value.length < 2) {
                    return 'Must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Jersey number
              TextFormField(
                controller: _jerseyCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: 'Jersey number',
                  hintText: '1 to 99',
                  prefixIcon: const Icon(Icons.tag),
                  errorText: _jerseyError,
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Jersey number is required';
                  final n = int.tryParse(value);
                  if (n == null) return 'Must be a number';
                  if (n < 1 || n > 99) return 'Must be between 1 and 99';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Position dropdown
              DropdownButtonFormField<PlayerPosition>(
                value: _position,
                decoration: const InputDecoration(
                  labelText: 'Position',
                  prefixIcon: Icon(Icons.sports_basketball_outlined),
                ),
                items: [
                  for (final p in PlayerPosition.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text('${p.code}  —  ${p.displayName}'),
                    ),
                ],
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _position = value);
                        }
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
                    : Text(
                        widget.isEditing ? 'Save Changes' : 'Add Player',
                      ),
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
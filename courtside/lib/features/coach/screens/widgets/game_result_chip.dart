import 'package:flutter/material.dart';

import '../../../../models/game.dart';

/// Compact chip showing a game's outcome:
/// - "Win" — green
/// - "Loss" — red
/// - "Live" — pulsing primary color (in progress)
/// - "—" — finished but no result set (shouldn't normally happen)
class GameResultChip extends StatelessWidget {
  const GameResultChip({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (label, bg, fg) = _styleFor(game, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  (String, Color, Color) _styleFor(Game g, ColorScheme cs) {
    if (!g.isFinished) {
      return ('LIVE', cs.primary, cs.onPrimary);
    }
    switch (g.result) {
      case GameResult.win:
        return ('WIN', Colors.green.shade100, Colors.green.shade900);
      case GameResult.loss:
        return ('LOSS', Colors.red.shade100, Colors.red.shade900);
      case null:
        return ('—', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }
}
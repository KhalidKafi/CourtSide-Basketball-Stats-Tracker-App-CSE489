import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/viewmodels/auth_notifier.dart';
import 'player_repository.dart';
import 'team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appDatabaseProvider));
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(appDatabaseProvider));
});
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/viewmodels/auth_notifier.dart';
import 'admin_repository.dart';
import 'game_repository.dart';
import 'player_repository.dart';
import 'super_admin_repository.dart';
import 'team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appDatabaseProvider));
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(appDatabaseProvider));
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(appDatabaseProvider));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(appDatabaseProvider));
});

final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(authRepositoryProvider),
  );
});
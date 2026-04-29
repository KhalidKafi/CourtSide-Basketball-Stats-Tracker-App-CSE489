import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/viewmodels/auth_notifier.dart';
import '../../features/coach/screens/coach_dashboard_screen.dart';
import '../../features/coach/screens/game_summary_screen.dart';
import '../../features/coach/screens/season_analytics_screen.dart';
import '../../features/coach/screens/player_profile_screen.dart';
import '../../features/coach/screens/team_detail_screen.dart';
import '../../features/coach/screens/game_list_screen.dart';
import '../../features/coach/screens/new_game_screen.dart';
import '../../features/coach/screens/live_game_screen.dart';
import '../../features/coach/screens/team_list_screen.dart';
import '../../features/super_admin/screens/super_admin_dashboard_screen.dart';
import '../utils/user_role.dart';

// ──────────────────────────────────────────────────────────────────────────
// Route paths
//
// Constants instead of magic strings. If we ever rename a path (say we
// move `/coach` to `/dashboard/coach`), this is the single place it
// changes — every `context.go(AppRoutes.coachHome)` call keeps working.
// ──────────────────────────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const coachHome = '/coach';
  static const adminHome = '/admin';
  static const superAdminHome = '/super-admin';

  static const coachTeams = '/coach/teams';
  static String coachTeamDetail(int teamId) => '/coach/teams/$teamId';
  static String teamGames(int teamId) => '/coach/teams/$teamId/games';
  static String newGame(int teamId) => '/coach/teams/$teamId/games/new';
  static String liveGame(int gameId) => '/coach/games/$gameId/live';
  static String gameSummary(int gameId) => '/coach/games/$gameId/summary';
  static String teamAnalytics(int teamId) =>
      '/coach/teams/$teamId/analytics';
  static String playerProfile(int teamId, int playerId) =>
      '/coach/teams/$teamId/players/$playerId';
}

// ──────────────────────────────────────────────────────────────────────────
// Riverpod-to-Listenable bridge
//
// go_router's `refreshListenable` expects a ChangeNotifier (or any
// Listenable). We subscribe to the auth provider once; whenever auth
// state changes, we call notifyListeners() so go_router re-runs its
// redirect function against the new state.
// ──────────────────────────────────────────────────────────────────────────

class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(Ref ref) {
    // ref.listen fires whenever the provider's value changes. We ignore
    // the previous/next values (underscore parameters) — we only care
    // THAT something changed.
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// ──────────────────────────────────────────────────────────────────────────
// The GoRouter provider
// ──────────────────────────────────────────────────────────────────────────

final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthRouterListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    debugLogDiagnostics: true, // prints navigation events to the console
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final goingTo = state.matchedLocation;

      // The splash screen handles its own bootstrap (load session, then
      // navigate). Don't fight it from here — return null to allow it.
      if (goingTo == AppRoutes.splash) return null;

      final user = auth.user;
      final isAuthRoute =
          goingTo == AppRoutes.login || goingTo == AppRoutes.register;

      // Case 1: logged out.
      // Only the auth routes are reachable; everything else bounces to login.
      if (user == null) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // Case 2: logged in but on an auth route.
      // Don't let a signed-in user see the login/register page; send them home.
      if (isAuthRoute) {
        return _homeForRole(user.role);
      }

      // Case 3: logged in and on a protected route — check role matches.
      // Coach trying to reach /admin? Redirect to /coach.
      final allowedHome = _homeForRole(user.role);
      if (!goingTo.startsWith(allowedHome)) {
        return allowedHome;
      }

      // All checks passed — allow navigation.
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.coachHome,
        builder: (_, __) => const CoachDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.coachTeams,
        builder: (_, __) => const TeamListScreen(),
      ),
      GoRoute(
        path: '/coach/teams/:teamId',
        builder: (_, state) {
          final teamId = int.parse(state.pathParameters['teamId']!);
          return TeamDetailScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: '/coach/teams/:teamId/games',
        builder: (_, state) {
          final teamId = int.parse(state.pathParameters['teamId']!);
          return GameListScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: '/coach/teams/:teamId/games/new',
        builder: (_, state) {
          final teamId = int.parse(state.pathParameters['teamId']!);
          return NewGameScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: '/coach/games/:gameId/live',
        builder: (_, state) {
          final gameId = int.parse(state.pathParameters['gameId']!);
          return LiveGameScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/coach/games/:gameId/summary',
        builder: (_, state) {
          final gameId = int.parse(state.pathParameters['gameId']!);
          return GameSummaryScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: '/coach/teams/:teamId/analytics',
        builder: (_, state) {
          final teamId = int.parse(state.pathParameters['teamId']!);
          return SeasonAnalyticsScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: '/coach/teams/:teamId/players/:playerId',
        builder: (_, state) {
          final teamId = int.parse(state.pathParameters['teamId']!);
          final playerId = int.parse(state.pathParameters['playerId']!);
          return PlayerProfileScreen(teamId: teamId, playerId: playerId);
        },
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.superAdminHome,
        builder: (_, __) => const SuperAdminDashboardScreen(),
      ),
    ],
  );
});

/// Maps a role to its dashboard path. Single source of truth — used
/// both in the redirect logic and (later) in the splash screen's
/// post-session navigation.
String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.coach:
      return AppRoutes.coachHome;
    case UserRole.admin:
      return AppRoutes.adminHome;
    case UserRole.superAdmin:
      return AppRoutes.superAdminHome;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/user_role.dart';
import '../viewmodels/auth_notifier.dart';

/// Splash screen — shown for the brief window while the persisted session
/// loads. After the session check resolves, navigates to:
///   - `/login`          if no session is found
///   - the role's home   if a valid session exists
///
/// This is the ONLY screen that manually navigates. Every other screen
/// lets the router's redirect decide where the user ends up.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // We can't call async code directly inside initState, but we can
    // schedule it to run after the first frame is drawn. This gives
    // the splash UI a moment to appear before the session load starts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(authNotifierProvider.notifier).loadSession();

    // After loadSession completes, the widget may have been unmounted
    // (e.g. if the user backgrounded the app). Always check `mounted`
    // before touching BuildContext from an async callback.
    if (!mounted) return;

    final user = ref.read(authNotifierProvider).user;

    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // Route to the appropriate dashboard based on role.
    switch (user.role) {
      case UserRole.coach:
        context.go(AppRoutes.coachHome);
        break;
      case UserRole.admin:
        context.go(AppRoutes.adminHome);
        break;
      case UserRole.superAdmin:
        context.go(AppRoutes.superAdminHome);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_basketball,
                size: 72,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CourtSide',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Basketball Stats Tracker',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

/// The root widget of the CourtSide app.
///
/// This is a thin shell: it pulls the router from Riverpod and wires up
/// MaterialApp.router. Any app-wide configuration (themes, localization)
/// will live here as the project grows.
class CourtSideApp extends ConsumerWidget {
  const CourtSideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'CourtSide',
      debugShowCheckedModeBanner: false,
      // Material 3 with a basketball-orange seed color.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
    );
  }
}
import 'package:flutter/material.dart';

import '../../auth/screens/role_dashboard_placeholder.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardPlaceholder(
      title: 'Admin Dashboard',
      icon: Icons.admin_panel_settings,
      upcomingFeatures: [
        'System overview with total coaches, teams, players, and games',
        'Browse all registered coaches',
        "Drill into any coach's teams and game history",
        'Recent activity feed of games and new accounts',
        'Search and filter coaches',
      ],
    );
  }
}
import 'package:flutter/material.dart';

import '../../auth/screens/role_dashboard_placeholder.dart';

class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardPlaceholder(
      title: 'Super Admin',
      icon: Icons.shield,
      upcomingFeatures: [
        'Create new Admin accounts with auto-generated or manual passwords',
        'View list of all registered Admins',
        'Reset any Admin password',
        'Delete Admin accounts',
      ],
    );
  }
}
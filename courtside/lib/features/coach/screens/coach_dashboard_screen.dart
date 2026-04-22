import 'package:flutter/material.dart';

import '../../auth/screens/role_dashboard_placeholder.dart';

class CoachDashboardScreen extends StatelessWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardPlaceholder(
      title: 'Coach Dashboard',
      icon: Icons.sports,
      upcomingFeatures: [
        'Create and manage your teams',
        'Add players with jersey numbers and positions',
        'Create new games and start live sessions',
        'Record live game stats with one-tap buttons',
        'View game summaries with FG%, 3P%, FT%',
        'Season analytics with charts and leaderboards',
        'Export reports as PDF or share as images',
      ],
    );
  }
}
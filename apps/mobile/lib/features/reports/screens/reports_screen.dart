import 'package:flutter/material.dart';

import '../../../shared/widgets/app_status.dart';
import '../../../shared/widgets/ui_primitives.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [SyncStatusButton()],
      ),
      body: const Column(
        children: [
          OfflineBanner(),
          Expanded(
            child: EmptyState(
              icon: Icons.bar_chart,
              message: 'Reports are not on this device yet.',
            ),
          ),
        ],
      ),
    );
  }
}

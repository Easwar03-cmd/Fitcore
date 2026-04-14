import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push(AppRoutes.friendSearch),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Social Feed — placeholder'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push(AppRoutes.challenges),
              child: const Text('Challenges'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.push(AppRoutes.leaderboard),
              child: const Text('Leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}

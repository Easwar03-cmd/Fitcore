import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// One-time dialog asking the user to grant health data access.

class HealthPermissionsDialog extends StatelessWidget {
  const HealthPermissionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sky,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(PhosphorIconsRegular.heartbeat,
                color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Connect Health Data',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revive would like to read and write:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 14),
          const PermissionRow(PhosphorIconsRegular.footprints, 'Steps',
              'Auto-fill your daily step count'),
          const PermissionRow(PhosphorIconsRegular.barbell, 'Workouts',
              'Write completed sessions back to your health app'),
          const SizedBox(height: 10),
          Text(
            'You can change these permissions any time in your device settings.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

class PermissionRow extends StatelessWidget {
  const PermissionRow(this.icon, this.title, this.subtitle, {super.key});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


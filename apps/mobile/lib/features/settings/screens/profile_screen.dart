import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final user = authAsync.valueOrNull?.user;
    final isLoading = authAsync.isLoading;

    final initial = user != null && user.name.isNotEmpty
        ? user.name[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Avatar header ─────────────────────────────────────────────
          _AvatarHeader(initial: initial, user: user),
          const SizedBox(height: 28),

          // ── Appearance group ──────────────────────────────────────────
          const _GroupLabel('Appearance'),
          const _ThemeToggleCard(),
          const SizedBox(height: 20),

          // ── Settings group ────────────────────────────────────────────
          const _GroupLabel('Settings'),
          _SettingsCard(
            items: [
              _TileData(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                onTap: () => context.push(AppRoutes.notificationPrefs),
              ),
              _TileData(
                icon: Icons.watch_rounded,
                label: 'Wearable Integrations',
                onTap: () => context.push(AppRoutes.wearableIntegrations),
              ),
              _TileData(
                icon: Icons.workspace_premium_rounded,
                label: 'Subscription',
                onTap: () => context.push(AppRoutes.subscription),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Account group ─────────────────────────────────────────────
          const _GroupLabel('Account'),
          _SettingsCard(
            items: [
              _TileData(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                color: AppColors.error,
                onTap: isLoading ? null : () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Log Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Avatar header ─────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.initial, required this.user});

  final String initial;
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primary.withAlpha(40),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user?.name ?? '',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Theme toggle card ─────────────────────────────────────────────────────────

class _ThemeToggleCard extends ConsumerWidget {
  const _ThemeToggleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pref = ref.watch(themeNotifierProvider);
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.palette_rounded, color: cs.onSurface, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Theme',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<ThemePreference>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: cs.onSurfaceVariant,
                ),
                segments: const [
                  ButtonSegment(
                    value: ThemePreference.auto,
                    icon: Icon(Icons.brightness_auto_rounded, size: 18),
                    tooltip: 'Auto',
                  ),
                  ButtonSegment(
                    value: ThemePreference.light,
                    icon: Icon(Icons.light_mode_rounded, size: 18),
                    tooltip: 'Light',
                  ),
                  ButtonSegment(
                    value: ThemePreference.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 18),
                    tooltip: 'Dark',
                  ),
                ],
                selected: {pref},
                onSelectionChanged: (selection) => ref
                    .read(themeNotifierProvider.notifier)
                    .setPreference(selection.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grouped card ──────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});
  final List<_TileData> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: cs.surfaceContainerHighest,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _SettingsTile(data: items[i]),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: cs.outline.withAlpha(50),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = data.color ?? cs.onSurface;
    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(data.icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

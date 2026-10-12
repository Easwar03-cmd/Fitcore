import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
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
      appBar: const PageAppBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          // ── Avatar header ─────────────────────────────────────────────
          _AvatarHeader(
            initial: initial,
            name: user?.name ?? '',
            email: user?.email ?? '',
          ),
          const SizedBox(height: 24),

          // ── Settings group ────────────────────────────────────────────
          const _GroupLabel('Settings'),
          _SettingsCard(
            items: [
              _TileData(
                icon: PhosphorIconsRegular.bell,
                tint: PastelTint.sky,
                label: 'Notifications',
                onTap: () => context.push(AppRoutes.notificationPrefs),
              ),
              _TileData(
                icon: PhosphorIconsRegular.crown,
                tint: PastelTint.butter,
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
                icon: PhosphorIconsRegular.signOut,
                tint: PastelTint.grey,
                label: 'Log Out',
                onTap: isLoading ? null : () => _confirmLogout(context, ref),
              ),
              _TileData(
                icon: PhosphorIconsRegular.trash,
                tint: PastelTint.salmon,
                label: 'Delete Account',
                onTap: isLoading ? null : () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        onConfirmed: () async {
          try {
            await ref.read(authProvider.notifier).deleteAccount();
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Failed to delete account: $e')),
              );
            }
          }
        },
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
                style: TextStyle(color: AppColors.coralText)),
          ),
        ],
      ),
    );
  }
}

// ── Avatar header (sky card) ──────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.initial,
    required this.name,
    required this.email,
  });

  final String initial;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.sky,
      radius: 28,
      padding: const EdgeInsets.all(20),
      semanticLabel: '$name, $email',
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Text(initial, style: AppTextStyles.title),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.metricM),
                const SizedBox(height: 4),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
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
      child: Semantics(
        header: true,
        child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 13)),
      ),
    );
  }
}

// ── Grouped card ──────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final PastelTint tint;
  final String label;
  final VoidCallback? onTap;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});
  final List<_TileData> items;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SettingsTile(data: items[i]),
            if (i < items.length - 1) const Divider(indent: 72, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

// ── Delete account confirmation dialog ───────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.onConfirmed});
  final Future<void> Function() onConfirmed;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool get _canConfirm => _ctrl.text.trim() == 'DELETE';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Delete Account'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will permanently delete your account and all your data — '
            'workouts, food logs, progress, everything. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          Text(
            'Type DELETE to confirm',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: (_canConfirm && !_loading)
              ? () async {
                  setState(() => _loading = true);
                  Navigator.of(context).pop();
                  await widget.onConfirmed();
                }
              : null,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete Forever'),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: data.onTap != null,
      label: data.label,
      child: InkWell(
        onTap: data.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: data.tint.color, shape: BoxShape.circle),
                  child: Icon(data.icon, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(data.label, style: AppTextStyles.bodyStrong),
                ),
                const Icon(PhosphorIconsRegular.caretRight, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

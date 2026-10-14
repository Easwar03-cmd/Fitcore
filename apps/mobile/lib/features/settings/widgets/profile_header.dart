import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';

/// Decodes a `data:image/...;base64,` avatar (null for anything else).
Uint8List? avatarBytes(String? url) {
  if (url == null || !url.startsWith('data:image')) return null;
  try {
    return base64Decode(url.substring(url.indexOf(',') + 1));
  } catch (_) {
    return null;
  }
}

/// Sky profile card: photo (tap to change), name, email and an edit button.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.user});
  final UserDto? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.name ?? '';
    final bytes = avatarBytes(user?.avatarUrl);
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return PastelCard(
      tint: PastelTint.sky,
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Change profile photo',
            child: GestureDetector(
              onTap: user == null ? null : () => _photoSheet(context, ref),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: bytes != null
                        ? Image.memory(bytes,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            gaplessPlayback: true)
                        : Text(initial, style: AppTextStyles.title),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: AppColors.ink, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.camera,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
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
                Text(user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'Edit profile',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
            ),
            onPressed: user == null ? null : () => _editName(context, ref),
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _photoSheet(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (user?.avatarUrl != null)
              ListTile(
                leading: const Icon(PhosphorIconsRegular.trash,
                    color: AppColors.coralText),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final notifier = ref.read(authProvider.notifier);

    try {
      if (choice == 'remove') {
        await notifier.updateMe(removeAvatar: true);
        return;
      }
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 72,
      );
      if (file == null) return;
      final data = base64Encode(await file.readAsBytes());
      await notifier.updateMe(avatarDataUri: 'data:image/jpeg;base64,$data');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your photo.')),
        );
      }
    }
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: user?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == user?.name) return;
    try {
      await ref.read(authProvider.notifier).updateMe(name: name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your name.')),
        );
      }
    }
  }
}

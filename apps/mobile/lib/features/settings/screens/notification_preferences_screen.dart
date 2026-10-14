import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/services/reminder_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../providers/notification_preferences_provider.dart';

String formatTime(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
}

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: const PageAppBar(title: 'Notifications'),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (prefs) => _PrefsBody(prefs: prefs),
      ),
    );
  }
}

const _icons = {
  ReminderKind.workout: PhosphorIconsRegular.barbell,
  ReminderKind.breakfast: PhosphorIconsRegular.coffee,
  ReminderKind.lunch: PhosphorIconsRegular.bowlFood,
  ReminderKind.dinner: PhosphorIconsRegular.forkKnife,
  ReminderKind.streak: PhosphorIconsRegular.flame,
};

class _PrefsBody extends ConsumerWidget {
  const _PrefsBody({required this.prefs});
  final NotificationPreferences prefs;

  Future<void> _save(WidgetRef ref, NotificationPreferences p) =>
      ref.read(notificationPreferencesProvider.notifier).save(p);

  Future<TimeOfDay?> _pick(BuildContext context, int hour, int minute) =>
      showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: hour, minute: minute),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = prefs.of(ReminderKind.values.first);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // ── Set every reminder at once ─────────────────────────────────────
        PastelCard(
          tint: PastelTint.sky,
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set all reminders at once', style: AppTextStyles.heading),
              const SizedBox(height: 4),
              Text(
                'Pick one time and every reminder is moved to it. You can '
                'still change each one below.',
                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final t = await _pick(context, first.hour, first.minute);
                      if (t == null) return;
                      await _save(
                        ref,
                        prefs.mapAll((r) => r.copyWith(
                              enabled: true,
                              hour: t.hour,
                              minute: t.minute,
                            )),
                      );
                    },
                    icon: const Icon(PhosphorIconsBold.clock, size: 18),
                    label: const Text('Choose time'),
                  ),
                  const Spacer(),
                  Text('All on', style: AppTextStyles.bodyStrong),
                  Switch(
                    value: prefs.allEnabled,
                    onChanged: (v) => _save(
                      ref,
                      prefs.mapAll((r) => r.copyWith(enabled: v)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── One row per reminder, each with its own time ───────────────────
        PastelCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final k in ReminderKind.values)
                _ReminderTile(
                  kind: k,
                  setting: prefs.of(k),
                  onToggle: (v) => _save(
                    ref,
                    prefs.withSetting(k, prefs.of(k).copyWith(enabled: v)),
                  ),
                  onPickTime: () async {
                    final s = prefs.of(k);
                    final t = await _pick(context, s.hour, s.minute);
                    if (t == null) return;
                    await _save(
                      ref,
                      prefs.withSetting(
                          k, s.copyWith(hour: t.hour, minute: t.minute)),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Weekly summary push notifications are sent every Sunday at 6 pm '
            'and cannot be disabled here — use your device settings to silence them.',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.kind,
    required this.setting,
    required this.onToggle,
    required this.onPickTime,
  });

  final ReminderKind kind;
  final ReminderSetting setting;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icons[kind], color: AppColors.ink),
      title: Text('${kind.label} reminder', style: AppTextStyles.bodyStrong),
      subtitle: Text(kind.description, style: AppTextStyles.caption),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: setting.enabled ? onPickTime : null,
            child: Text(
              formatTime(setting.hour, setting.minute),
              style: AppTextStyles.bodyStrong,
            ),
          ),
          Switch(value: setting.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

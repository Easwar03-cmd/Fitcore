import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/services/ble_heart_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/pastel_chip.dart';

/// Bluetooth LE section: live heart rate when connected, otherwise scan +
/// device list.
class BleSection extends ConsumerWidget {
  const BleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(bleHeartRateProvider);
    final ctl = ref.read(bleHeartRateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.isConnected)
          _LiveCard(
            name: s.connectedName ?? 'Device',
            bpm: s.bpm,
            battery: s.batteryPct,
            onDisconnect: () => ctl.disconnect(),
            onForget: () => ctl.disconnect(forget: true),
          )
        else ...[
          if (!s.adapterOn)
            const _Notice(
              icon: PhosphorIconsRegular.bluetoothSlash,
              text: 'Bluetooth is turned off. Turn it on to find your watch.',
            ),
          PastelCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pair any watch or band that shares heart rate over '
                  'Bluetooth. Keep it close and, on some watches, switch on '
                  '“heart rate broadcast”.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: s.adapterOn &&
                                s.status != BleStatus.scanning &&
                                s.status != BleStatus.connecting
                            ? ctl.startScan
                            : null,
                        icon: s.status == BleStatus.scanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(PhosphorIconsBold.bluetooth, size: 18),
                        label: Text(s.status == BleStatus.scanning
                            ? 'Scanning…'
                            : 'Find devices'),
                      ),
                    ),
                    if (s.rememberedName != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: s.adapterOn &&
                                s.status != BleStatus.connecting
                            ? ctl.reconnectRemembered
                            : null,
                        child: Text('Reconnect',
                            semanticsLabel: 'Reconnect ${s.rememberedName}'),
                      ),
                    ],
                  ],
                ),
                if (s.status == BleStatus.connecting) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Connecting to ${s.connectedName ?? 'device'}…',
                            style: AppTextStyles.body),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (s.message != null) ...[
            const SizedBox(height: 10),
            _Notice(icon: PhosphorIconsRegular.info, text: s.message!),
          ],
          if (s.devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in s.devices)
              _DeviceTile(
                device: d,
                onTap: s.status == BleStatus.connecting
                    ? null
                    : () => ctl.connectById(d.id, d.name),
              ),
          ] else if (s.status == BleStatus.idle &&
              s.message == null &&
              s.adapterOn) ...[
            const SizedBox(height: 4),
          ],
        ],
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.name,
    required this.bpm,
    required this.battery,
    required this.onDisconnect,
    required this.onForget,
  });

  final String name;
  final int? bpm;
  final int? battery;
  final VoidCallback onDisconnect;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.sky,
      radius: 28,
      padding: const EdgeInsets.all(18),
      semanticLabel:
          '$name connected. ${bpm == null ? 'Waiting for heart rate' : 'Heart rate $bpm beats per minute'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(PhosphorIconsFill.heartbeat,
                      size: 20, color: AppColors.coralText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading),
                ),
                if (battery != null)
                  PastelChip(
                    label: '$battery%',
                    icon: PhosphorIconsRegular.batteryMedium,
                    background: Colors.white,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(bpm?.toString() ?? '--', style: AppTextStyles.metricXL),
                const SizedBox(width: 8),
                Text('bpm live',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.ink)),
              ],
            ),
            if (bpm == null) ...[
              const SizedBox(height: 8),
              Text(
                'Connected, but the watch has not sent a heart rate yet. Many '
                'watches only stream while a workout or heart-rate screen is '
                'open, or when "heart rate broadcast" is switched on in the '
                'watch settings.',
                style: AppTextStyles.caption.copyWith(color: AppColors.ink),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                    onPressed: onDisconnect, child: const Text('Disconnect')),
                const SizedBox(width: 8),
                TextButton(onPressed: onForget, child: const Text('Forget')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});
  final BleDeviceInfo device;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PastelCard(
        radius: 20,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        semanticLabel:
            '${device.name}${device.advertisesHeartRate ? ', shares heart rate' : ''}. Tap to connect.',
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: device.advertisesHeartRate
                      ? AppColors.lime
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsRegular.watch, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong),
                    Text(
                      device.advertisesHeartRate
                          ? 'Shares heart rate'
                          : 'Signal ${device.rssi} dBm',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.caretRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return PastelCard(
      tint: PastelTint.butter,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

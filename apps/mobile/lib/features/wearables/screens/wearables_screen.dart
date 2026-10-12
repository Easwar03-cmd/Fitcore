import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/services/ble_heart_rate_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../providers/vitals_provider.dart';
import '../widgets/ble_section.dart';
import '../widgets/vitals_section.dart';

/// Wearables & health: Bluetooth live heart rate + sleep / rest / heart data
/// from the platform health store.
class WearablesScreen extends ConsumerStatefulWidget {
  const WearablesScreen({super.key});

  @override
  ConsumerState<WearablesScreen> createState() => _WearablesScreenState();
}

class _WearablesScreenState extends ConsumerState<WearablesScreen> {
  @override
  void initState() {
    super.initState();
    // Silently resume the previously paired device when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bleHeartRateProvider.notifier).reconnectRemembered();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Platform.isIOS ? 'Apple Health' : 'Health Connect';

    return Scaffold(
      appBar: PageAppBar(
        title: 'Wearables & health',
        actions: [
          CircleIconButton(
            icon: PhosphorIconsRegular.arrowClockwise,
            semanticLabel: 'Refresh health data',
            onPressed: () => ref.read(vitalsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vitalsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const HeroCard(
              tint: PastelTint.sky,
              chipLabel: 'Wearables',
              chipIcon: PhosphorIconsFill.watch,
              title: 'Connect your watch',
              subtitle: 'Heart rate, sleep and rest in one place',
              imageName: 'hero_fitband.jpg',
              fallbackIcon: PhosphorIconsRegular.watch,
            ),
            const _Label('Bluetooth heart rate'),
            const BleSection(),
            _Label('Sleep & rest · $store'),
            const VitalsSection(),
            const SizedBox(height: 20),
            Text(
              'Fitbit, Garmin, WHOOP and Oura accounts are not linked '
              'directly. Those devices sync to $store through their own '
              'apps, and Revive reads it from there.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTextStyles.heading),
      ),
    );
  }
}

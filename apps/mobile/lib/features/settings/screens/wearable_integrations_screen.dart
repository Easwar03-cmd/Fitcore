import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/health_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/wearable_provider.dart';

// ── OAuth configuration ───────────────────────────────────────────────────────
// To enable a provider:
//  1. Register your app on the provider's developer portal.
//  2. Set the environment variable below in your backend .env.
//  3. Replace the placeholder URL with the real OAuth authorisation URL.
//  4. Configure the deep-link redirect URI (revive://oauth/callback) in
//     AndroidManifest.xml (intent-filter) and iOS Info.plist (CFBundleURLTypes).
//
// The mobile app opens the OAuth URL in the browser. The provider redirects
// back to the deep link. GoRouter handles the deep link and POSTs the code to
// POST /api/v1/integrations/oauth/callback so the backend exchanges it for tokens.

const _kOAuthUrls = <String, String>{
  'fitbit':
      'https://www.fitbit.com/oauth2/authorize'
      '?response_type=code'
      '&client_id=YOUR_FITBIT_CLIENT_ID'
      '&redirect_uri=revive%3A%2F%2Foauth%2Fcallback'
      '&scope=activity+heartrate+sleep+weight'
      '&expires_in=604800',
  'garmin':
      'https://connect.garmin.com/oauthConfirm'
      '?oauth_token=REQUEST_TOKEN_HERE',  // Garmin uses OAuth 1.0a — get request token first
  'whoop':
      'https://api.prod.whoop.com/oauth/oauth2/auth'
      '?response_type=code'
      '&client_id=YOUR_WHOOP_CLIENT_ID'
      '&redirect_uri=revive%3A%2F%2Foauth%2Fcallback'
      '&scope=read%3Abody_measurement+read%3Acycles+read%3Asleep',
  'oura':
      'https://cloud.ouraring.com/oauth/authorize'
      '?response_type=code'
      '&client_id=YOUR_OURA_CLIENT_ID'
      '&redirect_uri=revive%3A%2F%2Foauth%2Fcallback'
      '&scope=personal+daily+heartrate+workout+session',
};

// ── Screen ────────────────────────────────────────────────────────────────────

class WearableIntegrationsScreen extends ConsumerStatefulWidget {
  const WearableIntegrationsScreen({super.key});

  @override
  ConsumerState<WearableIntegrationsScreen> createState() =>
      _WearableIntegrationsScreenState();
}

class _WearableIntegrationsScreenState
    extends ConsumerState<WearableIntegrationsScreen> {
  bool _healthConnected = false;
  bool _checkingHealth = true;

  @override
  void initState() {
    super.initState();
    _checkHealthPermissions();
  }

  Future<void> _checkHealthPermissions() async {
    final granted =
        await ref.read(healthServiceProvider).requestPermissions();
    if (mounted) {
      setState(() {
        _healthConnected = granted;
        _checkingHealth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wearableAsync = ref.watch(wearableProvider);
    final connected = wearableAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Integrations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(wearableProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Info banner ─────────────────────────────────────────────────────
          _InfoBanner(),
          const SizedBox(height: 20),

          // ── Platform health (Apple Health / Google Fit) ─────────────────────
          _SectionLabel(
            Platform.isIOS ? 'Apple Health' : 'Google Fit',
          ),
          const SizedBox(height: 8),
          _HealthCard(
            isConnected: _healthConnected,
            isChecking: _checkingHealth,
            onConnect: _checkHealthPermissions,
          ),
          const SizedBox(height: 24),

          // ── Third-party wearables ───────────────────────────────────────────
          const _SectionLabel('Third-Party Wearables'),
          const SizedBox(height: 8),
          ...['fitbit', 'garmin', 'whoop', 'oura'].map((provider) {
            final isConnected = connected.containsKey(provider);
            return _WearableCard(
              provider: provider,
              isConnected: isConnected,
              connectedAt: connected[provider]?.connectedAt,
              onConnect: () => _launchOAuth(provider),
              onDisconnect: () => _disconnect(provider),
            );
          }),

          if (wearableAsync.isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _launchOAuth(String provider) async {
    final urlStr = _kOAuthUrls[provider];
    if (urlStr == null) return;

    // Warn if client ID is still a placeholder.
    if (urlStr.contains('YOUR_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$provider OAuth is not configured. Set the client ID in the backend.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  Future<void> _disconnect(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect ${_displayName(provider)}?'),
        content: const Text(
            'Your data will no longer sync from this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(wearableProvider.notifier).disconnect(provider);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connect wearables to automatically sync sleep, heart rate, '
              'HRV, and activity data into your Wellness and Progress tabs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ── Platform health card (Apple Health / Google Fit) ─────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.isConnected,
    required this.isChecking,
    required this.onConnect,
  });

  final bool isConnected;
  final bool isChecking;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _ProviderIcon(
          icon: isIos ? Icons.favorite_rounded : Icons.sports_gymnastics_rounded,
          color: isIos ? AppColors.error : AppColors.info,
        ),
        title: Text(isIos ? 'Apple Health' : 'Google Fit',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isIos
              ? 'Steps, heart rate, sleep, weight & workouts'
              : 'Steps, heart rate, sleep & activity',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: isChecking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : isConnected
                ? _ConnectedBadge()
                : FilledButton.tonal(
                    onPressed: onConnect,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8)),
                    child: const Text('Grant Access'),
                  ),
      ),
    );
  }
}

// ── Third-party wearable card ─────────────────────────────────────────────────

class _WearableCard extends StatelessWidget {
  const _WearableCard({
    required this.provider,
    required this.isConnected,
    required this.connectedAt,
    required this.onConnect,
    required this.onDisconnect,
  });

  final String provider;
  final bool isConnected;
  final DateTime? connectedAt;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _providerStyle(provider);
    final name = _displayName(provider);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _ProviderIcon(icon: icon, color: color),
        title: Text(name,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isConnected && connectedAt != null
              ? 'Connected ${_formatDate(connectedAt!)}'
              : _providerSubtitle(provider),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: isConnected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConnectedBadge(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded,
                        color: AppColors.error, size: 20),
                    tooltip: 'Disconnect',
                    onPressed: onDisconnect,
                  ),
                ],
              )
            : FilledButton.tonal(
                onPressed: onConnect,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8)),
                child: const Text('Connect'),
              ),
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 13),
          const SizedBox(width: 4),
          Text('Connected',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.success)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _displayName(String provider) => switch (provider) {
      'fitbit' => 'Fitbit',
      'garmin' => 'Garmin Connect',
      'whoop' => 'WHOOP',
      'oura' => 'Oura Ring',
      _ => provider,
    };

(IconData, Color) _providerStyle(String provider) => switch (provider) {
      'fitbit' => (Icons.directions_run_rounded, const Color(0xFF00B0B9)),
      'garmin' => (Icons.watch_rounded, const Color(0xFF006B8F)),
      'whoop' => (Icons.monitor_heart_rounded, AppColors.error),
      'oura' => (Icons.nightlight_round, const Color(0xFF7B5EA7)),
      _ => (Icons.device_unknown_rounded, AppColors.onSurfaceVariant),
    };

String _providerSubtitle(String provider) => switch (provider) {
      'fitbit' => 'Sleep, HRV, steps, heart rate',
      'garmin' => 'Training load, sleep, VO2 max, HRV',
      'whoop' => 'Recovery, strain, sleep, HRV',
      'oura' => 'Readiness, sleep stages, HRV, activity',
      _ => '',
    };

String _formatDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

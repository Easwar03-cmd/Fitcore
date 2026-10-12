import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_app_bar.dart';
import '../../../core/widgets/pastel_card.dart';
import '../../../core/widgets/stat_row.dart';
import '../providers/interstitial_ad_provider.dart';
import '../providers/workout_provider.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key});

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _distanceLabel(double km) =>
      km < 1.0 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(2)} km';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-warm the interstitial so the ad has time to load before Done is tapped.
    ref.watch(interstitialAdProvider);

    final summary = ref.watch(workoutSessionProvider).summary;

    if (summary == null) {
      return const Scaffold(
        appBar: PageAppBar(title: 'Workout Summary'),
        body: Center(child: Text('No workout data.')),
      );
    }

    final hasRoute =
        summary.routePoints.length >= 2 && summary.distanceKm != null;

    return Scaffold(
      appBar: const PageAppBar(title: 'Workout Complete', showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // ── Title block ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Great Work!', style: AppTextStyles.title),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.workoutName} · '
                  '${DateFormat('d MMMM, y').format(DateTime.now())}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          // ── Stat rows (reference "Today's Activity") ──────────────────
          PastelCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
            child: Column(
              children: [
                StatRow(
                  tint: PastelTint.lime,
                  icon: PhosphorIconsRegular.timer,
                  value: _formatDuration(summary.durationMin),
                  label: 'Duration',
                ),
                StatRow(
                  tint: PastelTint.sky,
                  icon: PhosphorIconsRegular.listNumbers,
                  value: '${summary.totalSets}',
                  label: 'Total sets',
                ),
                StatRow(
                  tint: PastelTint.salmon,
                  icon: PhosphorIconsRegular.flame,
                  value: '~${summary.caloriesBurned} kcal',
                  label: 'Calories',
                  showDivider: summary.distanceKm != null,
                ),
                if (summary.distanceKm != null)
                  StatRow(
                    tint: PastelTint.butter,
                    icon: PhosphorIconsRegular.path,
                    value: _distanceLabel(summary.distanceKm!),
                    label: 'Distance covered',
                    showDivider: false,
                  ),
              ],
            ),
          )
              .animate()
              .slideY(begin: 0.15, delay: 150.ms, duration: 400.ms)
              .fadeIn(delay: 150.ms),

          // ── Route map (outdoor workouts with GPS data) ─────────────────
          if (hasRoute) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Route', style: AppTextStyles.heading),
            ),
            _RouteMap(points: summary.routePoints).animate().fadeIn(delay: 300.ms),
          ],

          // ── Exercises list ─────────────────────────────────────────────
          if (summary.exerciseNames.isNotEmpty) ...[
            const SizedBox(height: 20),
            PastelCard(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exercises', style: AppTextStyles.heading),
                  const SizedBox(height: 6),
                  ...summary.exerciseNames.indexed.map(
                    ((int, String) pair) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsFill.checkCircle, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(pair.$2, style: AppTextStyles.body)),
                        ],
                      ),
                    ).animate().fadeIn(
                        delay: Duration(milliseconds: 350 + pair.$1 * 60)),
                  ),
                ],
              ),
            ),
          ],

          // ── Done button ────────────────────────────────────────────────
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(workoutSessionProvider.notifier).resetSession();
              // Show interstitial for free users; navigate after it closes.
              ref.read(interstitialAdProvider.notifier).showIfReady(
                    context,
                    () => context.go(AppRoutes.workout),
                  );
            },
            child: const Text('Done'),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

// ── Route map ─────────────────────────────────────────────────────────────────

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.points});

  final List<LatLng> points;

  /// Compute map bounds that fit all route points with padding.
  LatLngBounds get _bounds {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Small padding so the route doesn't touch the map edge.
    const pad = 0.0005;
    return LatLngBounds(
      LatLng(minLat - pad, minLng - pad),
      LatLng(maxLat + pad, maxLng + pad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = _bounds;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(16),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none, // non-interactive in summary
            ),
          ),
          children: [
            // ── OpenStreetMap tile layer ────────────────────────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.revivefit.app',
            ),

            // ── Route polyline ──────────────────────────────────────────
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppColors.ink,
                  strokeWidth: 4.0,
                ),
              ],
            ),

            // ── Start marker ────────────────────────────────────────────
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 20,
                  height: 20,
                  child: const _RouteMarker(
                    color: Colors.green,
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
                Marker(
                  point: points.last,
                  width: 20,
                  height: 20,
                  child: _RouteMarker(
                    color: theme.colorScheme.error,
                    icon: Icons.flag_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

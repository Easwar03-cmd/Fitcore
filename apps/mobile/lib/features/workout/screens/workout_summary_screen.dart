import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../constants/app_routes.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-warm the interstitial so the ad has time to load before Done is tapped.
    ref.watch(interstitialAdProvider);

    final summary = ref.watch(workoutSessionProvider).summary;
    final theme = Theme.of(context);

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Summary')),
        body: const Center(child: Text('No workout data.')),
      );
    }

    final hasRoute =
        summary.routePoints.length >= 2 && summary.distanceKm != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          children: [
            // ── Trophy + heading ─────────────────────────────────────────
            Icon(
              Icons.emoji_events_rounded,
              size: 88,
              color: theme.colorScheme.primary,
            )
                .animate()
                .scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                    begin: const Offset(0.4, 0.4)),
            const SizedBox(height: 8),
            Text(
              'Great Work!',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 4),
            Text(
              summary.workoutName,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),

            // ── Stats row ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer_rounded,
                    label: 'Duration',
                    value: _formatDuration(summary.durationMin),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.format_list_numbered_rounded,
                    label: 'Total Sets',
                    value: '${summary.totalSets}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Calories',
                    value: '~${summary.caloriesBurned}',
                  ),
                ),
              ],
            )
                .animate()
                .slideY(begin: 0.3, delay: 400.ms, duration: 400.ms)
                .fadeIn(delay: 400.ms),

            // ── Distance card (outdoor workouts only) ────────────────────
            if (summary.distanceKm != null) ...[
              const SizedBox(height: 12),
              _DistanceCard(distanceKm: summary.distanceKm!)
                  .animate()
                  .slideY(begin: 0.3, delay: 440.ms, duration: 400.ms)
                  .fadeIn(delay: 440.ms),
            ],

            const SizedBox(height: 28),

            // ── Route map (outdoor workouts with GPS data) ───────────────
            if (hasRoute) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Route', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              _RouteMap(points: summary.routePoints)
                  .animate()
                  .fadeIn(delay: 500.ms),
              const SizedBox(height: 28),
            ],

            // ── Exercises list ───────────────────────────────────────────
            if (summary.exerciseNames.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Exercises',
                    style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 8),
              ...summary.exerciseNames.indexed.map(
                ((int, String) pair) => ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(pair.$2),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 500 + pair.$1 * 60)),
              ),
              const SizedBox(height: 24),
            ],

            // ── Done button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(workoutSessionProvider.notifier).resetSession();
                  // Show interstitial for free users; navigate after it closes.
                  ref.read(interstitialAdProvider.notifier).showIfReady(
                    context,
                    () => context.go(AppRoutes.workout),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}

// ── Shared stat card ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Distance card (wide, shown for outdoor workouts) ─────────────────────────

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.distanceKm});

  final double distanceKm;

  String get _label {
    if (distanceKm < 1.0) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.straighten_rounded,
                color: theme.colorScheme.primary, size: 26),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Distance covered',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(12),
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
              userAgentPackageName: 'com.revive.app',
            ),

            // ── Route polyline ──────────────────────────────────────────
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: theme.colorScheme.primary,
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

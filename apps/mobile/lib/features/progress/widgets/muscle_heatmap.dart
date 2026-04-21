import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Front-view body silhouette with muscle groups coloured by weekly set volume.
/// Back muscles (back, hamstrings, glutes) appear as labelled chips to the side
/// since they're not visible from the front.
class MuscleHeatmap extends StatelessWidget {
  const MuscleHeatmap({super.key, required this.volume});

  /// Keys: 'chest' | 'shoulders' | 'arms' | 'core' | 'quads' | 'calves' |
  ///       'back' | 'hamstrings' | 'glutes'
  final Map<String, int> volume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const _VolumeKey(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Front silhouette
            SizedBox(
              width: 160,
              height: 340,
              child: CustomPaint(painter: _BodyPainter(volume)),
            ),
            const SizedBox(width: 20),
            // Back-of-body muscle chips
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Back muscles',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                _MuscleChip('Back', volume['back'] ?? 0),
                const SizedBox(height: 6),
                _MuscleChip('Hamstrings', volume['hamstrings'] ?? 0),
                const SizedBox(height: 6),
                _MuscleChip('Glutes', volume['glutes'] ?? 0),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Front view  ·  sets this week',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Volume legend ──────────────────────────────────────────────────────────────

class _VolumeKey extends StatelessWidget {
  const _VolumeKey();

  static const _items = <(Color, String)>[
    (Color(0xFF2A2A3A), '0'),
    (Color(0xFF1E3A6E), '1-5'),
    (Color(0xFF1565C0), '6-10'),
    (Color(0xFF4B44CC), '11-15'),
    (Color(0xFFB71C1C), '16+'),
  ];

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.$1,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Text(item.$2, style: labelStyle),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Back-muscle chip ───────────────────────────────────────────────────────────

class _MuscleChip extends StatelessWidget {
  const _MuscleChip(this.name, this.sets);
  final String name;
  final int sets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _BodyPainter.volumeColor(sets),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          Text(
            '$sets sets',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body silhouette CustomPainter ──────────────────────────────────────────────
//
// Canvas: 160 × 340 logical pixels (front view).
// Body parts drawn back-to-front so shoulders appear behind the arms/chest.

class _BodyPainter extends CustomPainter {
  const _BodyPainter(this.volume);
  final Map<String, int> volume;

  // Exposed so _MuscleChip can reuse.
  static Color volumeColor(int sets) {
    if (sets <= 0) return const Color(0xFF2A2A3A);
    if (sets <= 5) return const Color(0xFF1E3A6E);
    if (sets <= 10) return const Color(0xFF1565C0);
    if (sets <= 15) return const Color(0xFF4B44CC);
    return const Color(0xFFB71C1C);
  }

  static const Color _neutral = Color(0xFF2A2A3A);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 160;
    final sy = size.height / 340;

    // Scale a logical-px rectangle to a canvas RRect.
    RRect rr(double l, double t, double r, double b, double rad) =>
        RRect.fromLTRBR(
          l * sx, t * sy, r * sx, b * sy, Radius.circular(rad),
        );

    Paint fill(String group) =>
        Paint()
          ..color = volumeColor(volume[group] ?? 0)
          ..style = PaintingStyle.fill;

    final neutralPaint = Paint()
      ..color = _neutral
      ..style = PaintingStyle.fill;

    // ── Back layer: shoulders (drawn first so arms/chest overlap edges) ─────
    canvas.drawRRect(rr(10, 34, 52, 72, 12), fill('shoulders')); // left
    canvas.drawRRect(rr(108, 34, 150, 72, 12), fill('shoulders')); // right

    // ── Chest ────────────────────────────────────────────────────────────────
    canvas.drawRRect(rr(44, 44, 78, 100, 8), fill('chest')); // left pec
    canvas.drawRRect(rr(82, 44, 116, 100, 8), fill('chest')); // right pec

    // ── Upper arms (biceps) ──────────────────────────────────────────────────
    canvas.drawRRect(rr(6, 72, 38, 152, 12), fill('arms')); // left
    canvas.drawRRect(rr(122, 72, 154, 152, 12), fill('arms')); // right

    // ── Core / abs ───────────────────────────────────────────────────────────
    canvas.drawRRect(rr(46, 102, 78, 166, 8), fill('core')); // left
    canvas.drawRRect(rr(82, 102, 114, 166, 8), fill('core')); // right

    // ── Forearms ─────────────────────────────────────────────────────────────
    canvas.drawRRect(rr(8, 154, 34, 218, 12), fill('arms')); // left
    canvas.drawRRect(rr(126, 154, 152, 218, 12), fill('arms')); // right

    // ── Pelvis / hip connector (neutral — glutes are posterior) ──────────────
    canvas.drawRRect(rr(44, 168, 116, 192, 8), neutralPaint);

    // ── Quads ─────────────────────────────────────────────────────────────────
    canvas.drawRRect(rr(34, 194, 74, 278, 14), fill('quads')); // left
    canvas.drawRRect(rr(86, 194, 126, 278, 14), fill('quads')); // right

    // ── Calves ────────────────────────────────────────────────────────────────
    canvas.drawRRect(rr(38, 280, 68, 340, 14), fill('calves')); // left
    canvas.drawRRect(rr(92, 280, 122, 340, 14), fill('calves')); // right

    // ── Head + neck (drawn last so they sit on top of shoulders) ─────────────
    canvas.drawRRect(rr(66, 28, 94, 44, 4), neutralPaint); // neck
    canvas.drawCircle(
      Offset(80 * sx, 18 * sy),
      14 * sx,
      neutralPaint,
    );
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.volume != volume;
}

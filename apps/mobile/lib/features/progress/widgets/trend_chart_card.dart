import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

class TrendPoint {
  const TrendPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

class TrendRange {
  const TrendRange(this.label, {this.days});

  /// Shown on the tab.
  final String label;

  /// Window ending at the newest point; null = everything.
  final int? days;
}

/// Range tabs + big value + date stepper + smooth line with a red scrubber
/// (reference "Heart Health" chart). Tap or drag on the chart to move the
/// selected point; the chevrons step through points.
class TrendChartCard extends StatefulWidget {
  const TrendChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    this.ranges = const [TrendRange('Days')],
    this.target,
    this.decimals = 0,
    this.emptyMessage = 'No data yet',
  });

  final String title;
  final String unit;
  final List<TrendPoint> points;
  final List<TrendRange> ranges;

  /// Optional dashed reference line (e.g. calorie target).
  final double? target;
  final int decimals;
  final String emptyMessage;

  @override
  State<TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<TrendChartCard> {
  int _range = 0;
  int? _selected; // index into the visible list; null = newest

  List<TrendPoint> get _visible {
    final all = [...widget.points]..sort((a, b) => a.date.compareTo(b.date));
    final days = widget.ranges[_range].days;
    if (days == null || all.isEmpty) return all;
    final cutoff = all.last.date.subtract(Duration(days: days));
    return all.where((p) => !p.date.isBefore(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pts = _visible;
    final idx = pts.isEmpty ? 0 : (_selected ?? pts.length - 1).clamp(0, pts.length - 1);
    final sel = pts.isEmpty ? null : pts[idx];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTextStyles.heading),
          const SizedBox(height: 10),
          if (widget.ranges.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.ranges.length; i++)
                  _Tab(
                    label: widget.ranges[i].label,
                    selected: i == _range,
                    onTap: () => setState(() {
                      _range = i;
                      _selected = null;
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (sel == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(widget.emptyMessage, style: AppTextStyles.caption),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(sel.value.toStringAsFixed(widget.decimals),
                          style: AppTextStyles.metricL),
                      const SizedBox(width: 4),
                      Text(widget.unit, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                _StepButton(
                  icon: PhosphorIconsBold.caretLeft,
                  label: 'Previous point',
                  onTap: idx > 0 ? () => setState(() => _selected = idx - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(DateFormat('d MMMM y').format(sel.date),
                      style: AppTextStyles.micro.copyWith(fontSize: 12)),
                ),
                _StepButton(
                  icon: PhosphorIconsBold.caretRight,
                  label: 'Next point',
                  onTap: idx < pts.length - 1
                      ? () => setState(() => _selected = idx + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder: (context, c) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth, pts.length),
                  onHorizontalDragUpdate: (d) =>
                      _pick(d.localPosition.dx, c.maxWidth, pts.length),
                  child: Semantics(
                    label:
                        '${widget.title}: ${sel.value.toStringAsFixed(widget.decimals)} ${widget.unit} on ${DateFormat('d MMMM').format(sel.date)}',
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        size: Size(c.maxWidth, 190),
                        painter: _TrendPainter(
                          points: pts,
                          selected: idx,
                          target: widget.target,
                          decimals: widget.decimals,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _pick(double dx, double width, int count) {
    if (count < 2) return;
    const plotLeft = _TrendPainter.leftPad;
    final plotW = width - plotLeft - _TrendPainter.rightPad;
    final t = ((dx - plotLeft) / plotW).clamp(0.0, 1.0);
    final i = (t * (count - 1)).round();
    if (i != _selected) setState(() => _selected = i);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 56),
          child: Center(
            child: Container(
              padding: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: 36,
          height: 44,
          child: Icon(icon,
              size: 14,
              color: onTap == null ? AppColors.track : AppColors.ink),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.selected,
    required this.target,
    required this.decimals,
  });

  final List<TrendPoint> points;
  final int selected;
  final double? target;
  final int decimals;

  static const double leftPad = 34;
  static const double rightPad = 6;
  static const double topPad = 14;
  static const double bottomPad = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
        leftPad, topPad, size.width - rightPad, size.height - bottomPad);

    var lo = points.map((p) => p.value).reduce(math.min);
    var hi = points.map((p) => p.value).reduce(math.max);
    if (target != null) {
      lo = math.min(lo, target!);
      hi = math.max(hi, target!);
    }
    final span = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
    lo -= span * 0.15;
    hi += span * 0.15;

    double xAt(int i) => points.length == 1
        ? plot.center.dx
        : plot.left + plot.width * i / (points.length - 1);
    double yAt(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    // ── Grid + y labels ────────────────────────────────────────────────────
    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    const rows = 4;
    for (var r = 0; r <= rows; r++) {
      final y = plot.top + plot.height * r / rows;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final v = hi - (hi - lo) * r / rows;
      _text(canvas, v.toStringAsFixed(decimals > 0 ? 1 : 0),
          Offset(0, y - 6), AppColors.inkMuted, 10);
    }

    // ── Target line ────────────────────────────────────────────────────────
    if (target != null) {
      final y = yAt(target!);
      final dash = Paint()
        ..color = AppColors.inkMuted
        ..strokeWidth = 1.2;
      for (double x = plot.left; x < plot.right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, plot.right), y), dash);
      }
    }

    // ── Smooth line ────────────────────────────────────────────────────────
    final offs = [for (var i = 0; i < points.length; i++) Offset(xAt(i), yAt(points[i].value))];
    if (offs.length > 1) {
      final path = Path()..moveTo(offs.first.dx, offs.first.dy);
      for (var i = 0; i < offs.length - 1; i++) {
        final p0 = offs[i];
        final p1 = offs[i + 1];
        final mx = (p0.dx + p1.dx) / 2;
        path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = AppColors.tealBright,
      );
    }

    // ── Scrubber ───────────────────────────────────────────────────────────
    final s = offs[selected];
    canvas.drawLine(
      Offset(s.dx, plot.top),
      Offset(s.dx, plot.bottom),
      Paint()
        ..color = AppColors.coral
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(s, 7, Paint()..color = Colors.white);
    canvas.drawCircle(s, 5, Paint()..color = AppColors.coral);

    // ── x labels (first / middle / last date) ──────────────────────────────
    final fmt = DateFormat('d MMM');
    final idxs = {0, points.length ~/ 2, points.length - 1}.toList()..sort();
    for (final i in idxs) {
      final label = fmt.format(points[i].date);
      final tp = _layout(label, AppColors.inkMuted, 10);
      var x = xAt(i) - tp.width / 2;
      x = x.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, size.height - 14));
    }
  }

  TextPainter _layout(String t, Color c, double size) => TextPainter(
        text: TextSpan(
          text: t,
          style: AppTextStyles.micro.copyWith(color: c, fontSize: size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _text(Canvas canvas, String t, Offset o, Color c, double size) =>
      _layout(t, c, size).paint(canvas, o);

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.target != target ||
      old.decimals != decimals;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../models/food_analysis.dart';

class DetectedFoodCard extends StatefulWidget {
  const DetectedFoodCard({
    super.key,
    required this.item,
    required this.index,
    required this.onToggle,
    required this.onServingChanged,
    required this.onRemove,
  });

  final DetectedFoodItem item;
  final int index;
  final VoidCallback onToggle;
  final ValueChanged<double> onServingChanged;
  final VoidCallback onRemove;

  @override
  State<DetectedFoodCard> createState() => _DetectedFoodCardState();
}

class _DetectedFoodCardState extends State<DetectedFoodCard> {
  late TextEditingController _servingCtrl;

  @override
  void initState() {
    super.initState();
    _servingCtrl = TextEditingController(
      text: widget.item.servingG.round().toString(),
    );
  }

  @override
  void didUpdateWidget(DetectedFoodCard old) {
    super.didUpdateWidget(old);
    final newVal = widget.item.servingG.round().toString();
    if (_servingCtrl.text != newVal) {
      _servingCtrl.text = newVal;
    }
  }

  @override
  void dispose() {
    _servingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final dimmed = !item.isSelected;

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: item.isSelected
              ? const BorderSide(color: AppColors.primary, width: 1.4)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: item.isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: item.isSelected
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: item.isSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.foodName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _ConfidenceBadge(confidence: item.confidence),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Macro row ────────────────────────────────────────────────
              Row(
                children: [
                  _MacroChip('${item.calories.round()} kcal', AppColors.calories),
                  const SizedBox(width: 6),
                  _MacroChip('${item.proteinG.round()}g P', AppColors.protein),
                  const SizedBox(width: 6),
                  _MacroChip('${item.carbsG.round()}g C', AppColors.carbs),
                  const SizedBox(width: 6),
                  _MacroChip('${item.fatG.round()}g F', AppColors.fat),
                ],
              ),
              const SizedBox(height: 10),
              // ── Serving adjuster ─────────────────────────────────────────
              Row(
                children: [
                  Text('Serving:',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  _ServingAdjustButton(
                    icon: Icons.remove,
                    onPressed: () {
                      final current = item.servingG;
                      if (current > 10) {
                        final next = (current - 10).clamp(10, 9999).toDouble();
                        widget.onServingChanged(next);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    height: 32,
                    child: TextField(
                      controller: _servingCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        isDense: true,
                        suffix: Text('g',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        const _MaxValueFormatter(2000),
                      ],
                      onSubmitted: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val > 0) {
                          widget.onServingChanged(val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ServingAdjustButton(
                    icon: Icons.add,
                    onPressed: () {
                      final next = (item.servingG + 10).clamp(10, 2000).toDouble();
                      widget.onServingChanged(next);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 50 * widget.index), duration: 280.ms)
        .slideX(begin: 0.04, end: 0, duration: 280.ms);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  const _MacroChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final String confidence;

  static const _colors = {
    'high': Color(0xFF4CAF50),
    'medium': Color(0xFFFFB300),
    'low': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[confidence] ?? const Color(0xFFFFB300);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        confidence,
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ServingAdjustButton extends StatelessWidget {
  const _ServingAdjustButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  const _MaxValueFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final val = int.tryParse(next.text);
    if (val != null && val > max) return old;
    return next;
  }
}

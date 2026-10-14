import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// − [ value unit ] + control used by the log-food sheet.
///
/// The parent owns the value and decides what a step means (10 g for a free
/// amount, 1 for a serving count).
class AmountStepper extends StatefulWidget {
  const AmountStepper({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.onStep,
    this.canDecrease = true,
    this.errorText,
  });

  final String value;
  final String unit;
  final ValueChanged<String> onChanged;

  /// +1 or −1.
  final ValueChanged<int> onStep;
  final bool canDecrease;
  final String? errorText;

  @override
  State<AmountStepper> createState() => _AmountStepperState();
}

class _AmountStepperState extends State<AmountStepper> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(AmountStepper old) {
    super.didUpdateWidget(old);
    // Keep the field in sync with stepper / chip changes, but never fight the
    // user's own typing (the parent echoes it back unchanged).
    if (double.tryParse(widget.value) != double.tryParse(_c.text) ||
        (double.tryParse(widget.value) == null && widget.value != _c.text)) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundButton(
          icon: PhosphorIconsBold.minus,
          label: 'Decrease amount',
          onTap: widget.canDecrease ? () => widget.onStep(-1) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _c,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: InputDecoration(
              suffixText: widget.unit,
              errorText: widget.errorText,
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 12),
        _RoundButton(
          icon: PhosphorIconsBold.plus,
          label: 'Increase amount',
          onTap: () => widget.onStep(1),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? AppColors.track : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

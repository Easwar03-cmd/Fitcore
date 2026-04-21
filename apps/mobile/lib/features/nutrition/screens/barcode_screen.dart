import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/nutrition_provider.dart';
import '../widgets/food_result_card.dart';
import '../widgets/log_food_sheet.dart';

class BarcodeScreen extends ConsumerStatefulWidget {
  const BarcodeScreen({super.key});

  @override
  ConsumerState<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends ConsumerState<BarcodeScreen> {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    ref.read(foodBarcodeProvider.notifier).reset();
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final rawValue = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    _scanned = true;
    _scanner.stop();
    ref.read(foodBarcodeProvider.notifier).lookupBarcode(rawValue);
  }

  void _resetScan() {
    setState(() => _scanned = false);
    ref.read(foodBarcodeProvider.notifier).reset();
    _scanner.start();
  }

  void _toggleTorch() {
    _scanner.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    final barcodeState = ref.watch(foodBarcodeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flashlight_on : Icons.flashlight_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(controller: _scanner, onDetect: _onDetect),

          // Scan-area overlay with dimming + corner markers
          const _ScanOverlay(),

          // Instruction label
          if (!_scanned)
            const Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Point camera at a barcode',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),

          // Result panel slides in from the bottom
          barcodeState.when(
            loading: () => const _ResultPanel(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => _ResultPanel(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resetScan,
                      child: const Text('Scan again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (item) {
              if (item == null && !_scanned) return const SizedBox.shrink();
              if (item == null) {
                return _ResultPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Product not found in database',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _resetScan,
                          child: const Text('Scan again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _ResultPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FoodResultCard(item: item),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetScan,
                              child: const Text('Scan again'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final logged =
                                    await showLogFoodSheet(context, item);
                                if (logged && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Add to log'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Scan overlay ─────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.36),
      width: size.width * 0.76,
      height: size.width * 0.4,
    );

    // Dim everything outside the cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(cutout, const Radius.circular(12))),
      ),
      Paint()..color = Colors.black54,
    );

    // Corner tick marks
    const len = 24.0;
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void corner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, p);
      canvas.drawLine(a, c, p);
    }

    corner(
      cutout.topLeft,
      cutout.topLeft + const Offset(len, 0),
      cutout.topLeft + const Offset(0, len),
    );
    corner(
      cutout.topRight,
      cutout.topRight + const Offset(-len, 0),
      cutout.topRight + const Offset(0, len),
    );
    corner(
      cutout.bottomLeft,
      cutout.bottomLeft + const Offset(len, 0),
      cutout.bottomLeft + const Offset(0, -len),
    );
    corner(
      cutout.bottomRight,
      cutout.bottomRight + const Offset(-len, 0),
      cutout.bottomRight + const Offset(0, -len),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Result panel ─────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 16),
          ],
        ),
        child: child,
      ),
    );
  }
}

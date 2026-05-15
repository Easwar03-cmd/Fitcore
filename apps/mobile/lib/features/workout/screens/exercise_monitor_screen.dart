import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_feedback.dart';
import '../providers/exercise_monitor_provider.dart';
import '../services/pose_analyzer.dart';
import '../widgets/form_feedback_card.dart';
import '../widgets/gemini_tip_card.dart';
import '../widgets/pose_overlay_painter.dart';

class ExerciseMonitorScreen extends ConsumerStatefulWidget {
  const ExerciseMonitorScreen({super.key});

  @override
  ConsumerState<ExerciseMonitorScreen> createState() =>
      _ExerciseMonitorScreenState();
}

class _ExerciseMonitorScreenState
    extends ConsumerState<ExerciseMonitorScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isFrontCamera = true;
  bool _isInitializing = true;
  String? _initError;
  String _selectedExerciseId = kMonitorableExercises.first;

  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initCamera(front: true);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera({required bool front}) async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }

      final camera = front
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first,
            )
          : cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      _camera = camera;
      _isFrontCamera = camera.lensDirection == CameraLensDirection.front;

      final formatGroup = Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21;

      final ctrl = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: formatGroup,
      );

      await ctrl.initialize();
      if (!mounted) return;

      _controller = ctrl;
      setState(() => _isInitializing = false);
      await ctrl.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Camera error: $e';
          _isInitializing = false;
        });
      }
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameTime) < const Duration(milliseconds: 150)) {
      return;
    }
    _lastFrameTime = now;

    final inputImage = _toInputImage(image);
    if (inputImage == null) return;

    final rotation = _computeRotation();
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    ref.read(exerciseMonitorProvider.notifier).processImage(
          inputImage,
          _isFrontCamera,
          imageSize,
          rotation,
        );
  }

  InputImage? _toInputImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _computeRotation(),
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _computeRotation() {
    final camera = _camera;
    if (camera == null) return InputImageRotation.rotation0deg;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    final deviceDeg = switch (_controller?.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };

    final compensation = _isFrontCamera
        ? (camera.sensorOrientation + deviceDeg) % 360
        : (camera.sensorOrientation - deviceDeg + 360) % 360;

    return InputImageRotationValue.fromRawValue(compensation) ??
        InputImageRotation.rotation0deg;
  }

  void _selectExercise(String id) {
    setState(() => _selectedExerciseId = id);
    ref.read(exerciseMonitorProvider.notifier).setExercise(id);
  }

  Future<void> _switchCamera() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
    await _initCamera(front: !_isFrontCamera);
  }

  void _showExercisePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExercisePickerSheet(
        selectedId: _selectedExerciseId,
        onSelect: (id) {
          Navigator.pop(context);
          _selectExercise(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(exerciseMonitorProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-screen camera + skeleton overlay
          _buildCameraView(monitorState),

          // 2. Top control bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // 3. Good form badge (top-right, below controls)
          if (monitorState.feedback.level == FeedbackLevel.good &&
              monitorState.currentPose != null)
            const Positioned(
              top: 120,
              right: 20,
              child: _GoodFormBadge(),
            ),

          // 4. Bottom overlay: exercise selector + AI tips + feedback card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomOverlay(monitorState),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
              ),
              const Expanded(
                child: Text(
                  'AI Form Monitor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cameraswitch_rounded,
                    color: Colors.white),
                onPressed: _isInitializing ? null : _switchCamera,
                tooltip: 'Switch camera',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () =>
                    ref.read(exerciseMonitorProvider.notifier).resetReps(),
                tooltip: 'Reset reps',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(ExerciseMonitorState monitorState) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xDD000000), Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise selector pill
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 10),
                child: _ExerciseSelectorPill(
                  exerciseName:
                      kMonitorableNames[_selectedExerciseId] ?? _selectedExerciseId,
                  onTap: _showExercisePicker,
                ),
              ),

              // Gemini AI tip card
              if (monitorState.isGeminiAnalyzing ||
                  monitorState.geminiTip != null)
                GeminiTipCard(
                  tip: monitorState.geminiTip,
                  isAnalyzing: monitorState.isGeminiAnalyzing,
                ),

              // ML Kit rule-based feedback card
              FormFeedbackCard(
                feedback: monitorState.feedback,
                repCount: monitorState.repCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(ExerciseMonitorState monitorState) {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _initError!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isInitializing || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final preview = _controller!.value.previewSize;
      final previewW = preview?.height ?? constraints.maxWidth;
      final previewH = preview?.width ?? constraints.maxHeight;

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          if (monitorState.currentPose == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.accessibility_new_rounded,
                      color: Colors.white24, size: 96),
                  SizedBox(height: 8),
                  Text(
                    'Point camera at your body',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (monitorState.currentPose != null &&
              monitorState.imageSize != Size.zero)
            CustomPaint(
              painter: PoseOverlayPainter(
                pose: monitorState.currentPose!,
                imageSize: monitorState.imageSize,
                rotation: monitorState.imageRotation,
                isFrontCamera: monitorState.isFrontCamera,
                feedbackLevel: monitorState.feedback.level,
              ),
            ),
        ],
      );
    });
  }
}

// ── Exercise selector pill ────────────────────────────────────────────────────

class _ExerciseSelectorPill extends StatelessWidget {
  const _ExerciseSelectorPill(
      {required this.exerciseName, required this.onTap});

  final String exerciseName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E40AF).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3B82F6), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              exerciseName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Exercise picker bottom sheet ──────────────────────────────────────────────

class _ExercisePickerSheet extends StatelessWidget {
  const _ExercisePickerSheet(
      {required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  static const Map<String, IconData> _icons = {
    'squat': Icons.accessibility_new_rounded,
    'lunge': Icons.directions_walk_rounded,
    'push_up': Icons.fitness_center,
    'plank': Icons.horizontal_rule_rounded,
    'deadlift': Icons.fitness_center,
    'romanian_dl': Icons.sports_gymnastics,
    'overhead_press': Icons.arrow_upward_rounded,
    'bicep_curl': Icons.sports_gymnastics,
    'pull_up': Icons.keyboard_double_arrow_up_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Exercise',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: kMonitorableNames.length,
            itemBuilder: (_, index) {
              final id = kMonitorableNames.keys.elementAt(index);
              final name = kMonitorableNames[id]!;
              final isSelected = id == selectedId;
              return GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: 180.ms,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[id] ?? Icons.fitness_center,
                        color: isSelected
                            ? Colors.white
                            : Colors.white60,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

// ── Good form badge ───────────────────────────────────────────────────────────

class _GoodFormBadge extends StatelessWidget {
  const _GoodFormBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF166534).withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Color(0xFF86EFAC),
        size: 32,
      ),
    )
        .animate()
        .scale(begin: const Offset(0.5, 0.5), duration: 300.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 200.ms);
  }
}

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_feedback.dart';
import '../providers/exercise_monitor_provider.dart';
import '../services/pose_analyzer.dart';
import '../widgets/form_feedback_card.dart';
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
  CameraDescription? _camera; // stored so rotation can be computed per-frame
  bool _isFrontCamera = true;
  bool _isInitializing = true;
  String? _initError;
  String _selectedExerciseId = kMonitorableExercises.first;

  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera(front: true);
  }

  @override
  void dispose() {
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

      // NV21 on Android, bgra8888 on iOS — the only formats ML Kit accepts.
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

  // ── Frame processing ──────────────────────────────────────────────────────

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

  /// Converts a [CameraImage] to an [InputImage] that ML Kit can process.
  /// Returns null if the format is unsupported (frame is skipped silently).
  InputImage? _toInputImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // ML Kit accepts nv21 on Android and bgra8888 on iOS only.
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    // Both nv21 and bgra8888 are packed into a single plane.
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

  /// Computes the correct [InputImageRotation] for the current device +
  /// camera combination. On Android the device orientation must be combined
  /// with the sensor orientation; on iOS the sensor value is used directly.
  InputImageRotation _computeRotation() {
    final camera = _camera;
    if (camera == null) return InputImageRotation.rotation0deg;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    // Android: map DeviceOrientation → degrees then combine with sensor.
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

  // ── UI ────────────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(exerciseMonitorProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('AI Form Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: _isInitializing ? null : _switchCamera,
            tooltip: 'Switch camera',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(exerciseMonitorProvider.notifier).resetReps(),
            tooltip: 'Reset reps',
          ),
        ],
      ),
      body: Column(
        children: [
          _ExerciseChips(
            selectedId: _selectedExerciseId,
            onSelect: _selectExercise,
          ),
          Expanded(child: _buildCameraView(monitorState)),
          FormFeedbackCard(
            feedback: monitorState.feedback,
            repCount: monitorState.repCount,
          ),
        ],
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
      // previewSize is in landscape (width > height); swap for portrait display.
      final preview = _controller!.value.previewSize;
      final previewW = preview?.height ?? constraints.maxWidth;
      final previewH = preview?.width ?? constraints.maxHeight;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
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

          // "Step into frame" hint when no person is detected
          if (monitorState.currentPose == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.accessibility_new_rounded,
                    color: Colors.white24,
                    size: 96,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Point camera at your body',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Skeleton overlay — only drawn when a pose is detected
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

          // Green check badge — only when pose IS detected AND form is good
          if (monitorState.feedback.level == FeedbackLevel.good &&
              monitorState.currentPose != null)
            const Positioned(
              top: 20,
              right: 20,
              child: _GoodFormBadge(),
            ),
        ],
      );
    });
  }
}

// ── Exercise chip selector ────────────────────────────────────────────────────

class _ExerciseChips extends StatelessWidget {
  const _ExerciseChips({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: kMonitorableNames.entries.map((entry) {
          final isSelected = entry.key == selectedId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => onSelect(entry.key),
              selectedColor: const Color(0xFF3B82F6),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: const Color(0xFF374151),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : Colors.white24,
              ),
            ),
          );
        }).toList(),
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
    );
  }
}

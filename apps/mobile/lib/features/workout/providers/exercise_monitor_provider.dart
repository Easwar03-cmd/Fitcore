import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_feedback.dart';
import '../services/pose_analyzer.dart';
import '../services/pose_smoother.dart';

class ExerciseMonitorState {
  const ExerciseMonitorState({
    this.feedback = PoseFeedback.noPose,
    this.currentPose,
    this.imageSize = Size.zero,
    this.imageRotation = InputImageRotation.rotation0deg,
    this.isFrontCamera = true,
    this.repCount = 0,
  });

  final PoseFeedback feedback;
  final Pose? currentPose;
  final Size imageSize;
  final InputImageRotation imageRotation;
  final bool isFrontCamera;
  final int repCount;

  ExerciseMonitorState copyWith({
    PoseFeedback? feedback,
    Pose? currentPose,
    bool clearPose = false,
    Size? imageSize,
    InputImageRotation? imageRotation,
    bool? isFrontCamera,
    int? repCount,
  }) =>
      ExerciseMonitorState(
        feedback: feedback ?? this.feedback,
        currentPose: clearPose ? null : (currentPose ?? this.currentPose),
        imageSize: imageSize ?? this.imageSize,
        imageRotation: imageRotation ?? this.imageRotation,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        repCount: repCount ?? this.repCount,
      );
}

class ExerciseMonitorNotifier extends StateNotifier<ExerciseMonitorState> {
  ExerciseMonitorNotifier() : super(const ExerciseMonitorState()) {
    _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
  }

  late final PoseDetector _detector;
  final PoseSmoother _smoother = PoseSmoother();

  bool _isProcessing = false;
  String _exerciseId = kMonitorableExercises.first;

  // ── Feedback debouncing ─────────────────────────────────────────────────
  // Require 2 consecutive frames with the same feedback before updating UI.
  // Prevents single-frame glitches from flashing on screen.
  PoseFeedback _pendingFeedback = PoseFeedback.noPose;
  int _pendingCount = 0;
  static const _kDebounceFrames = 2;

  // ── Phase-based rep counter ─────────────────────────────────────────────
  // A rep = primary angle passes through bottom threshold then returns to top.
  bool _hitBottom = false;
  int _repCount = 0;

  void setExercise(String id) {
    _exerciseId = id;
    _smoother.reset();
    _pendingFeedback = PoseFeedback.noPose;
    _pendingCount = 0;
    _hitBottom = false;
    _repCount = 0;
    state = state.copyWith(
      repCount: 0,
      clearPose: true,
      feedback: PoseFeedback.noPose,
    );
  }

  void resetReps() {
    _hitBottom = false;
    _repCount = 0;
    state = state.copyWith(repCount: 0);
  }

  Future<void> processImage(
    InputImage inputImage,
    bool isFrontCamera,
    Size imageSize,
    InputImageRotation rotation,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final poses = await _detector.processImage(inputImage);
      if (!mounted) return;

      if (poses.isEmpty) {
        _applyFeedback(
          PoseFeedback.noPose,
          clearPose: true,
          imageSize: imageSize,
          rotation: rotation,
          isFrontCamera: isFrontCamera,
          pose: null,
        );
        return;
      }

      // Apply EMA smoothing to reduce per-frame jitter.
      final smoothed = _smoother.update(poses.first);

      final rawFeedback = PoseAnalyzer.analyze(_exerciseId, smoothed);

      // Phase-based rep counting using the exercise's primary angle.
      _updateRepCount(_exerciseId, smoothed, rawFeedback);

      _applyFeedback(
        rawFeedback,
        clearPose: false,
        imageSize: imageSize,
        rotation: rotation,
        isFrontCamera: isFrontCamera,
        pose: smoothed,
      );
    } catch (e) {
      debugPrint('PoseDetector error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Debounced feedback update ───────────────────────────────────────────

  void _applyFeedback(
    PoseFeedback feedback, {
    required bool clearPose,
    required Size imageSize,
    required InputImageRotation rotation,
    required bool isFrontCamera,
    required Pose? pose,
  }) {
    if (feedback.level == _pendingFeedback.level &&
        feedback.message == _pendingFeedback.message) {
      _pendingCount++;
    } else {
      _pendingFeedback = feedback;
      _pendingCount = 1;
    }

    // Only push to UI once the feedback has been stable for N frames.
    if (_pendingCount < _kDebounceFrames) return;

    state = state.copyWith(
      feedback: feedback,
      clearPose: clearPose,
      currentPose: pose,
      imageSize: imageSize,
      imageRotation: rotation,
      isFrontCamera: isFrontCamera,
      repCount: _repCount,
    );
  }

  // ── Phase-based rep counter ─────────────────────────────────────────────

  void _updateRepCount(String exerciseId, Pose pose, PoseFeedback feedback) {
    // Plank is a hold — no rep counting.
    if (exerciseId == 'plank') return;
    // Don't count reps when the user isn't in position yet.
    if (feedback.level == FeedbackLevel.none) return;

    final thresholds = kRepThresholds[exerciseId];
    if (thresholds == null || thresholds.bottom == 0) return;

    final angle = PoseAnalyzer.primaryAngle(exerciseId, pose);
    if (angle.isNaN) return;

    if (angle <= thresholds.bottom) {
      _hitBottom = true;
    } else if (angle >= thresholds.top && _hitBottom) {
      _repCount++;
      _hitBottom = false;
    }
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }
}

final exerciseMonitorProvider = StateNotifierProvider.autoDispose<
    ExerciseMonitorNotifier, ExerciseMonitorState>(
  (_) => ExerciseMonitorNotifier(),
);

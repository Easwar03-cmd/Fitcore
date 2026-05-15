import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:logger/logger.dart';

import '../../../core/api/api_client.dart';
import '../models/pose_feedback.dart';
import '../services/pose_analyzer.dart';
import '../services/pose_smoother.dart';

final _log = Logger();

class ExerciseMonitorState {
  const ExerciseMonitorState({
    this.feedback = PoseFeedback.noPose,
    this.currentPose,
    this.imageSize = Size.zero,
    this.imageRotation = InputImageRotation.rotation0deg,
    this.isFrontCamera = true,
    this.repCount = 0,
    this.geminiTip,
    this.isGeminiAnalyzing = false,
  });

  final PoseFeedback feedback;
  final Pose? currentPose;
  final Size imageSize;
  final InputImageRotation imageRotation;
  final bool isFrontCamera;
  final int repCount;
  final GeminiFormFeedback? geminiTip;
  final bool isGeminiAnalyzing;

  ExerciseMonitorState copyWith({
    PoseFeedback? feedback,
    Pose? currentPose,
    bool clearPose = false,
    Size? imageSize,
    InputImageRotation? imageRotation,
    bool? isFrontCamera,
    int? repCount,
    GeminiFormFeedback? geminiTip,
    bool clearGeminiTip = false,
    bool? isGeminiAnalyzing,
  }) =>
      ExerciseMonitorState(
        feedback: feedback ?? this.feedback,
        currentPose: clearPose ? null : (currentPose ?? this.currentPose),
        imageSize: imageSize ?? this.imageSize,
        imageRotation: imageRotation ?? this.imageRotation,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        repCount: repCount ?? this.repCount,
        geminiTip: clearGeminiTip ? null : (geminiTip ?? this.geminiTip),
        isGeminiAnalyzing: isGeminiAnalyzing ?? this.isGeminiAnalyzing,
      );
}

class ExerciseMonitorNotifier extends StateNotifier<ExerciseMonitorState> {
  ExerciseMonitorNotifier(this._ref) : super(const ExerciseMonitorState()) {
    _detector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    // Periodic Gemini analysis — fires every 12 s while the screen is open.
    _geminiTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _maybeAnalyzeWithGemini();
    });
  }

  final Ref _ref;
  late final PoseDetector _detector;
  final PoseSmoother _smoother = PoseSmoother();
  Timer? _geminiTimer;

  bool _isProcessing = false;
  String _exerciseId = kMonitorableExercises.first;

  // ── Feedback debouncing ─────────────────────────────────────────────────────
  PoseFeedback _pendingFeedback = PoseFeedback.noPose;
  int _pendingCount = 0;
  static const _kDebounceFrames = 2;

  // ── Phase-based rep counter ─────────────────────────────────────────────────
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
      clearGeminiTip: true,
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

      final smoothed = _smoother.update(poses.first);
      final rawFeedback = PoseAnalyzer.analyze(_exerciseId, smoothed);
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

  // ── Gemini periodic coaching ────────────────────────────────────────────────

  Future<void> _maybeAnalyzeWithGemini() async {
    final s = state;
    if (s.currentPose == null) return;
    if (s.feedback.level == FeedbackLevel.none) return;
    if (s.isGeminiAnalyzing) return;
    if (!mounted) return;

    state = state.copyWith(isGeminiAnalyzing: true);

    try {
      final angle = PoseAnalyzer.primaryAngle(_exerciseId, s.currentPose!);
      final dio = _ref.read(apiClientProvider).dio;
      final res = await dio.post<Map<String, dynamic>>(
        '/ai/form-analysis',
        data: {
          'exerciseName': kMonitorableNames[_exerciseId] ?? _exerciseId,
          'currentFeedback': s.feedback.message,
          'feedbackLevel': s.feedback.level.name,
          'primaryAngleDeg': angle.isNaN ? null : angle,
          'repCount': s.repCount,
        },
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (!mounted) return;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        state = state.copyWith(isGeminiAnalyzing: false);
        return;
      }

      final tips = (data['tips'] as List? ?? []).cast<String>();
      final encouragement = data['encouragement'] as String? ?? 'Keep it up!';

      state = state.copyWith(
        isGeminiAnalyzing: false,
        geminiTip: GeminiFormFeedback(tips: tips, encouragement: encouragement),
      );
    } on DioException catch (e, st) {
      _log.w('Gemini form analysis failed', error: e, stackTrace: st);
      if (mounted) state = state.copyWith(isGeminiAnalyzing: false);
    } catch (e, st) {
      _log.w('Gemini form analysis error', error: e, stackTrace: st);
      if (mounted) state = state.copyWith(isGeminiAnalyzing: false);
    }
  }

  // ── Debounced feedback update ───────────────────────────────────────────────

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

  // ── Phase-based rep counter ─────────────────────────────────────────────────

  void _updateRepCount(String exerciseId, Pose pose, PoseFeedback feedback) {
    if (exerciseId == 'plank') return;
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
    _geminiTimer?.cancel();
    _detector.close();
    super.dispose();
  }
}

final exerciseMonitorProvider = StateNotifierProvider.autoDispose<
    ExerciseMonitorNotifier, ExerciseMonitorState>(
  (ref) => ExerciseMonitorNotifier(ref),
);

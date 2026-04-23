import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_feedback.dart';

/// Draws the ML Kit skeleton over the camera preview, with:
///  - Full body connections including neck/head
///  - Larger joint dots for visibility
///  - Color-coded by form feedback level
class PoseOverlayPainter extends CustomPainter {
  const PoseOverlayPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
    required this.feedbackLevel,
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;
  final FeedbackLevel feedbackLevel;

  Color get _color => switch (feedbackLevel) {
        FeedbackLevel.none  => const Color(0xFF9CA3AF),
        FeedbackLevel.good  => const Color(0xFF22C55E),
        FeedbackLevel.warn  => const Color(0xFFF59E0B),
        FeedbackLevel.error => const Color(0xFFEF4444),
      };

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final bonePaint = Paint()
      ..color = _color
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.fill;

    // Faint white halo under the skeleton so it's visible on any background.
    final haloPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lms = pose.landmarks;

    // ── Skeleton connections ─────────────────────────────────────────────
    const connections = <(PoseLandmarkType, PoseLandmarkType)>[
      // Head → shoulders
      (PoseLandmarkType.nose,          PoseLandmarkType.leftShoulder),
      (PoseLandmarkType.nose,          PoseLandmarkType.rightShoulder),
      // Torso
      (PoseLandmarkType.leftShoulder,  PoseLandmarkType.rightShoulder),
      (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftHip),
      (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
      (PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip),
      // Left arm
      (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftElbow),
      (PoseLandmarkType.leftElbow,     PoseLandmarkType.leftWrist),
      // Right arm
      (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
      (PoseLandmarkType.rightElbow,    PoseLandmarkType.rightWrist),
      // Left leg
      (PoseLandmarkType.leftHip,       PoseLandmarkType.leftKnee),
      (PoseLandmarkType.leftKnee,      PoseLandmarkType.leftAnkle),
      (PoseLandmarkType.leftAnkle,     PoseLandmarkType.leftFootIndex),
      // Right leg
      (PoseLandmarkType.rightHip,      PoseLandmarkType.rightKnee),
      (PoseLandmarkType.rightKnee,     PoseLandmarkType.rightAnkle),
      (PoseLandmarkType.rightAnkle,    PoseLandmarkType.rightFootIndex),
    ];

    for (final (a, b) in connections) {
      final lmA = lms[a];
      final lmB = lms[b];
      if (lmA == null || lmB == null) continue;
      if (lmA.likelihood < 0.4 || lmB.likelihood < 0.4) continue;

      final pA = _toScreen(lmA.x, lmA.y, canvasSize);
      final pB = _toScreen(lmB.x, lmB.y, canvasSize);
      canvas.drawLine(pA, pB, haloPaint); // halo first
      canvas.drawLine(pA, pB, bonePaint);
    }

    // ── Joint dots ───────────────────────────────────────────────────────
    const keyPoints = <PoseLandmarkType>[
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,   PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,        PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,       PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,      PoseLandmarkType.rightAnkle,
    ];

    final haloDot = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (final type in keyPoints) {
      final lm = lms[type];
      if (lm == null || lm.likelihood < 0.4) continue;
      final pt = _toScreen(lm.x, lm.y, canvasSize);
      canvas.drawCircle(pt, 8.0, haloDot);
      canvas.drawCircle(pt, 6.0, dotPaint);
    }
  }

  /// Maps a landmark from ML Kit display space to canvas pixels.
  ///
  /// ML Kit returns x/y already in the rotated (portrait) coordinate system.
  /// We only need to handle the axis flip specific to each rotation value,
  /// then apply the FittedBox.cover scale + crop offset to match the preview.
  Offset _toScreen(double lmX, double lmY, Size canvasSize) {
    final imgW = imageSize.width;
    final imgH = imageSize.height;

    // Effective display dimensions after sensor rotation.
    final bool is90or270 = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final double srcW = is90or270 ? imgH : imgW;
    final double srcH = is90or270 ? imgW : imgH;

    // Axis correction per rotation value (matches official ML Kit coordinate
    // convention for Flutter).
    double dx, dy;
    switch (rotation) {
      case InputImageRotation.rotation270deg:
        // Front camera, sensorOrientation 270°: x runs right→left in ML Kit.
        dx = srcW - lmX;
        dy = lmY;
      case InputImageRotation.rotation90deg:
        // Back camera, sensorOrientation 90°: x is already left→right.
        // Front camera with 90° sensor: mirror x.
        dx = isFrontCamera ? srcW - lmX : lmX;
        dy = lmY;
      case InputImageRotation.rotation180deg:
        dx = isFrontCamera ? lmX : srcW - lmX;
        dy = srcH - lmY;
      default: // 0°
        dx = isFrontCamera ? srcW - lmX : lmX;
        dy = lmY;
    }

    // FittedBox.cover: uniform scale so content fills canvas; excess is cropped.
    final scale   = math.max(canvasSize.width / srcW, canvasSize.height / srcH);
    final offsetX = (canvasSize.width  - srcW * scale) / 2;
    final offsetY = (canvasSize.height - srcH * scale) / 2;

    return Offset(dx * scale + offsetX, dy * scale + offsetY);
  }

  @override
  bool shouldRepaint(PoseOverlayPainter old) =>
      old.pose != pose || old.feedbackLevel != feedbackLevel;
}

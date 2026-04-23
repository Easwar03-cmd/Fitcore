import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_feedback.dart';

const Set<String> kMonitorableExercises = {
  'squat',
  'lunge',
  'push_up',
  'plank',
  'deadlift',
  'romanian_dl',
  'overhead_press',
  'bicep_curl',
  'pull_up',
};

const Map<String, String> kMonitorableNames = {
  'squat': 'Squat',
  'lunge': 'Lunge',
  'push_up': 'Push-Up',
  'plank': 'Plank',
  'deadlift': 'Deadlift',
  'romanian_dl': 'Romanian DL',
  'overhead_press': 'OHP',
  'bicep_curl': 'Bicep Curl',
  'pull_up': 'Pull-Up',
};

// ── Rep-phase thresholds ──────────────────────────────────────────────────────
// Each exercise has a "primary angle" that drives rep counting.
// A rep = angle crosses bottomThreshold then returns past topThreshold.

class RepThresholds {
  const RepThresholds({required this.bottom, required this.top});
  final double bottom; // angle must go ≤ this to confirm "at depth"
  final double top;    // angle must return ≥ this to complete the rep
}

const Map<String, RepThresholds> kRepThresholds = {
  'squat':          RepThresholds(bottom: 110, top: 155),
  'lunge':          RepThresholds(bottom: 110, top: 155),
  'push_up':        RepThresholds(bottom: 110, top: 155),
  'plank':          RepThresholds(bottom: 0,   top: 0),   // hold — no reps
  'deadlift':       RepThresholds(bottom: 100, top: 155),
  'romanian_dl':    RepThresholds(bottom: 100, top: 155),
  'overhead_press': RepThresholds(bottom: 100, top: 155),
  'bicep_curl':     RepThresholds(bottom: 65,  top: 150),
  'pull_up':        RepThresholds(bottom: 90,  top: 150),
};

class PoseAnalyzer {
  // ── Public API ────────────────────────────────────────────────────────────

  static PoseFeedback analyze(String exerciseId, Pose pose) {
    try {
      return switch (exerciseId) {
        'squat'          => _checkSquat(pose),
        'lunge'          => _checkLunge(pose),
        'push_up'        => _checkPushUp(pose),
        'plank'          => _checkPlank(pose),
        'deadlift'       => _checkDeadlift(pose),
        'romanian_dl'    => _checkRomanianDL(pose),
        'overhead_press' => _checkOverheadPress(pose),
        'bicep_curl'     => _checkBicepCurl(pose),
        'pull_up'        => _checkPullUp(pose),
        _                => PoseFeedback.ready,
      };
    } catch (_) {
      return PoseFeedback.ready;
    }
  }

  /// Returns the primary angle for rep-phase detection, or [double.nan]
  /// when the required landmarks are not reliably visible.
  static double primaryAngle(String exerciseId, Pose pose) {
    try {
      return switch (exerciseId) {
        'squat' || 'lunge' => _avgKneeAngle(pose),
        'push_up'          => _avgElbowAngle(pose),
        'plank'            => double.nan,
        'deadlift' || 'romanian_dl' => _hipHingeAngle(pose),
        'overhead_press'   => _avgElbowAngle(pose),
        'bicep_curl'       => _avgElbowAngle(pose),
        'pull_up'          => _singleElbowAngle(pose),
        _                  => double.nan,
      };
    } catch (_) {
      return double.nan;
    }
  }

  // ── Shared angle extractors ───────────────────────────────────────────────

  static double _avgKneeAngle(Pose pose) {
    final lHip   = _get(pose, PoseLandmarkType.leftHip);
    final lKnee  = _get(pose, PoseLandmarkType.leftKnee);
    final lAnkle = _get(pose, PoseLandmarkType.leftAnkle);
    final rHip   = _get(pose, PoseLandmarkType.rightHip);
    final rKnee  = _get(pose, PoseLandmarkType.rightKnee);
    final rAnkle = _get(pose, PoseLandmarkType.rightAnkle);

    final lValid = lHip != null && lKnee != null && lAnkle != null &&
        _vis(lHip) && _vis(lKnee) && _vis(lAnkle);
    final rValid = rHip != null && rKnee != null && rAnkle != null &&
        _vis(rHip) && _vis(rKnee) && _vis(rAnkle);

    if (lValid && rValid) {
      return (_ang(lHip, lKnee, lAnkle) + _ang(rHip, rKnee, rAnkle)) / 2;
    }
    if (lValid) return _ang(lHip, lKnee, lAnkle);
    if (rValid) return _ang(rHip, rKnee, rAnkle);
    return double.nan;
  }

  static double _avgElbowAngle(Pose pose) {
    final lS = _get(pose, PoseLandmarkType.leftShoulder);
    final lE = _get(pose, PoseLandmarkType.leftElbow);
    final lW = _get(pose, PoseLandmarkType.leftWrist);
    final rS = _get(pose, PoseLandmarkType.rightShoulder);
    final rE = _get(pose, PoseLandmarkType.rightElbow);
    final rW = _get(pose, PoseLandmarkType.rightWrist);

    final lValid = lS != null && lE != null && lW != null && _vis(lE);
    final rValid = rS != null && rE != null && rW != null && _vis(rE);

    if (lValid && rValid) return (_ang(lS, lE, lW) + _ang(rS, rE, rW)) / 2;
    if (lValid) return _ang(lS, lE, lW);
    if (rValid) return _ang(rS, rE, rW);
    return double.nan;
  }

  static double _singleElbowAngle(Pose pose) {
    final lS = _get(pose, PoseLandmarkType.leftShoulder);
    final lE = _get(pose, PoseLandmarkType.leftElbow);
    final lW = _get(pose, PoseLandmarkType.leftWrist);
    if (lS != null && lE != null && lW != null && _vis(lE)) {
      return _ang(lS, lE, lW);
    }
    final rS = _get(pose, PoseLandmarkType.rightShoulder);
    final rE = _get(pose, PoseLandmarkType.rightElbow);
    final rW = _get(pose, PoseLandmarkType.rightWrist);
    if (rS != null && rE != null && rW != null && _vis(rE)) {
      return _ang(rS, rE, rW);
    }
    return double.nan;
  }

  static double _hipHingeAngle(Pose pose) {
    final lS = _get(pose, PoseLandmarkType.leftShoulder);
    final lH = _get(pose, PoseLandmarkType.leftHip);
    final lK = _get(pose, PoseLandmarkType.leftKnee);
    final rS = _get(pose, PoseLandmarkType.rightShoulder);
    final rH = _get(pose, PoseLandmarkType.rightHip);
    final rK = _get(pose, PoseLandmarkType.rightKnee);

    final lValid = lS != null && lH != null && lK != null && _vis(lH);
    final rValid = rS != null && rH != null && rK != null && _vis(rH);

    if (lValid && rValid) return (_ang(lS, lH, lK) + _ang(rS, rH, rK)) / 2;
    if (lValid) return _ang(lS, lH, lK);
    if (rValid) return _ang(rS, rH, rK);
    return double.nan;
  }

  // ── Exercise checks ───────────────────────────────────────────────────────

  static PoseFeedback _checkSquat(Pose pose) {
    final lHip    = _get(pose, PoseLandmarkType.leftHip);
    final lKnee   = _get(pose, PoseLandmarkType.leftKnee);
    final lAnkle  = _get(pose, PoseLandmarkType.leftAnkle);
    final rHip    = _get(pose, PoseLandmarkType.rightHip);
    final rKnee   = _get(pose, PoseLandmarkType.rightKnee);
    final rAnkle  = _get(pose, PoseLandmarkType.rightAnkle);
    final lSh     = _get(pose, PoseLandmarkType.leftShoulder);
    final rSh     = _get(pose, PoseLandmarkType.rightShoulder);

    if (lHip == null || lKnee == null || lAnkle == null ||
        rHip == null || rKnee == null || rAnkle == null ||
        lSh == null  || rSh == null) return PoseFeedback.ready;
    if (!_vis(lKnee) || !_vis(rKnee) || !_vis(lHip)) return PoseFeedback.ready;

    final avgKnee = (_ang(lHip, lKnee, lAnkle) + _ang(rHip, rKnee, rAnkle)) / 2;
    if (avgKnee > 155) return PoseFeedback.ready; // standing — not in squat yet

    // Knee valgus: knees should track over toes, not cave inward.
    final kneeWidth = (lKnee.x - rKnee.x).abs();
    final ankleWidth = (lAnkle.x - rAnkle.x).abs();
    if (ankleWidth > 0 && kneeWidth < ankleWidth * 0.65) {
      return const PoseFeedback(
        level: FeedbackLevel.warn,
        message: 'Push knees out',
      );
    }

    // Excessive forward torso lean
    final torsoLean = _torsoLeanDeg(lSh, rSh, lHip, rHip);
    if (torsoLean > 55) {
      return const PoseFeedback(
        level: FeedbackLevel.warn,
        message: 'Keep chest up',
      );
    }

    // Squat depth — gently encourage going deeper
    if (avgKnee > 130) {
      return const PoseFeedback(
        level: FeedbackLevel.warn,
        message: 'Squat deeper',
      );
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkLunge(Pose pose) {
    final lHip    = _get(pose, PoseLandmarkType.leftHip);
    final lKnee   = _get(pose, PoseLandmarkType.leftKnee);
    final lAnkle  = _get(pose, PoseLandmarkType.leftAnkle);
    final rHip    = _get(pose, PoseLandmarkType.rightHip);
    final rKnee   = _get(pose, PoseLandmarkType.rightKnee);
    final rAnkle  = _get(pose, PoseLandmarkType.rightAnkle);
    final lSh     = _get(pose, PoseLandmarkType.leftShoulder);
    final rSh     = _get(pose, PoseLandmarkType.rightShoulder);

    if (lHip == null || lKnee == null || lAnkle == null ||
        rHip == null || rKnee == null || rAnkle == null ||
        lSh == null  || rSh == null) return PoseFeedback.ready;
    if (!_vis(lKnee) || !_vis(rKnee)) return PoseFeedback.ready;

    final lKA = _ang(lHip, lKnee, lAnkle);
    final rKA = _ang(rHip, rKnee, rAnkle);
    final frontKnee = min(lKA, rKA);

    if (frontKnee > 155) return PoseFeedback.ready;

    final torsoLean = _torsoLeanDeg(lSh, rSh, lHip, rHip);
    if (torsoLean > 20) {
      return const PoseFeedback(
        level: FeedbackLevel.warn,
        message: 'Keep torso upright',
      );
    }
    if (frontKnee < 70) {
      return const PoseFeedback(
        level: FeedbackLevel.warn,
        message: 'Step forward more',
      );
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkPushUp(Pose pose) {
    final lSh  = _get(pose, PoseLandmarkType.leftShoulder);
    final lE   = _get(pose, PoseLandmarkType.leftElbow);
    final lW   = _get(pose, PoseLandmarkType.leftWrist);
    final lH   = _get(pose, PoseLandmarkType.leftHip);
    final lAnk = _get(pose, PoseLandmarkType.leftAnkle);

    if (lSh == null || lE == null || lW == null ||
        lH == null || lAnk == null) return PoseFeedback.ready;
    if (!_vis(lSh) || !_vis(lH)) return PoseFeedback.ready;

    // ── Engagement: body must be roughly horizontal (not standing) ──────────
    // When lying down, shoulder and ankle are at similar y values (horizontal).
    // When standing, shoulder.y << ankle.y (large vertical span).
    final vertSpan = (lAnk.y - lSh.y).abs();
    final horizSpan = (lAnk.x - lSh.x).abs() + 1; // +1 avoids div-by-zero
    if (vertSpan > horizSpan * 1.2) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Get on the floor — face down',
      );
    }

    // Body alignment: shoulder–hip–ankle should form a straight line (~180°).
    final bodyAngle = _ang(lSh, lH, lAnk);
    if (bodyAngle < 155) {
      final midY = (lSh.y + lAnk.y) / 2;
      if (lH.y < midY - 10) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Lower hips — pike detected');
      }
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Raise hips — body sagging');
    }

    // Elbow angle during the down phase
    if (_vis(lE)) {
      final elbowAngle = _ang(lSh, lE, lW);
      if (elbowAngle < 65) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Tuck elbows slightly inward');
      }
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkPlank(Pose pose) {
    final lSh  = _get(pose, PoseLandmarkType.leftShoulder);
    final lH   = _get(pose, PoseLandmarkType.leftHip);
    final lAnk = _get(pose, PoseLandmarkType.leftAnkle);
    final rSh  = _get(pose, PoseLandmarkType.rightShoulder);
    final rH   = _get(pose, PoseLandmarkType.rightHip);
    final rAnk = _get(pose, PoseLandmarkType.rightAnkle);

    if (lSh == null || lH == null || lAnk == null ||
        rSh == null || rH == null || rAnk == null) return PoseFeedback.ready;
    if (!_vis(lSh) || !_vis(lH)) return PoseFeedback.ready;

    // ── Engagement: body must be roughly horizontal (not standing) ──────────
    final shMidY  = (lSh.y + rSh.y) / 2;
    final ankMidY = (lAnk.y + rAnk.y) / 2;
    final shMidX  = (lSh.x + rSh.x) / 2;
    final ankMidX = (lAnk.x + rAnk.x) / 2;
    final vertSpan  = (ankMidY - shMidY).abs();
    final horizSpan = (ankMidX - shMidX).abs() + 1;
    if (vertSpan > horizSpan * 1.2) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Get into plank position',
      );
    }

    final avg = (_ang(lSh, lH, lAnk) + _ang(rSh, rH, rAnk)) / 2;
    if (avg < 160) {
      final hipMidY = (lH.y + rH.y) / 2;
      final midY    = (shMidY + ankMidY) / 2;
      if (hipMidY < midY - 15) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Lower hips — piking');
      }
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Raise hips — sagging');
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkDeadlift(Pose pose) {
    final lSh  = _get(pose, PoseLandmarkType.leftShoulder);
    final rSh  = _get(pose, PoseLandmarkType.rightShoulder);
    final lH   = _get(pose, PoseLandmarkType.leftHip);
    final rH   = _get(pose, PoseLandmarkType.rightHip);
    final lK   = _get(pose, PoseLandmarkType.leftKnee);
    final lEar = _get(pose, PoseLandmarkType.leftEar);

    if (lSh == null || lH == null || rSh == null || rH == null) return PoseFeedback.ready;
    if (!_vis(lSh) || !_vis(lH)) return PoseFeedback.ready;

    // ── Engagement: shoulders must have dropped toward hips (hip hinge) ─────
    // When standing upright, shoulder midpoint is well above the hip midpoint.
    // When hinging, shoulders descend toward hip level.
    final shMidY  = (lSh.y + rSh.y) / 2;
    final hipMidY = (lH.y  + rH.y)  / 2;
    final shWidth = (lSh.x - rSh.x).abs() + 1;
    // y increases downward; hipMidY > shMidY when upright (hip is lower).
    // The gap shrinks as the person hinges. Threshold ≈ 1.7× shoulder-width.
    if ((hipMidY - shMidY) > shWidth * 1.7) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Hinge at the hips to start',
      );
    }

    // Neutral spine: ear–shoulder–hip angle should be ~180°.
    if (lEar != null && _vis(lEar)) {
      final spineAngle = _ang(lEar, lSh, lH);
      if (spineAngle < 145) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Keep back flat — no rounding');
      }
    }

    // Hips rising ahead of bar — shoulder–hip–knee should not be over-acute.
    if (lK != null && _vis(lK)) {
      final hipHinge = _ang(lSh, lH, lK);
      if (hipHinge < 90) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Drive hips forward');
      }
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkRomanianDL(Pose pose) {
    final lSh  = _get(pose, PoseLandmarkType.leftShoulder);
    final rSh  = _get(pose, PoseLandmarkType.rightShoulder);
    final lH   = _get(pose, PoseLandmarkType.leftHip);
    final rH   = _get(pose, PoseLandmarkType.rightHip);
    final lEar = _get(pose, PoseLandmarkType.leftEar);

    if (lSh == null || lH == null || rSh == null || rH == null) return PoseFeedback.ready;
    if (!_vis(lSh) || !_vis(lH)) return PoseFeedback.ready;

    // ── Engagement: same hip-hinge gate as deadlift ──────────────────────────
    final shMidY  = (lSh.y + rSh.y) / 2;
    final hipMidY = (lH.y  + rH.y)  / 2;
    final shWidth = (lSh.x - rSh.x).abs() + 1;
    if ((hipMidY - shMidY) > shWidth * 1.7) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Hinge at the hips to start',
      );
    }

    // Neutral spine check (key cue for RDL — hamstring stretch with flat back).
    if (lEar != null && _vis(lEar)) {
      final spineAngle = _ang(lEar, lSh, lH);
      if (spineAngle < 150) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Keep back straight');
      }
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkOverheadPress(Pose pose) {
    final lSh = _get(pose, PoseLandmarkType.leftShoulder);
    final lE  = _get(pose, PoseLandmarkType.leftElbow);
    final lW  = _get(pose, PoseLandmarkType.leftWrist);
    final rSh = _get(pose, PoseLandmarkType.rightShoulder);
    final rE  = _get(pose, PoseLandmarkType.rightElbow);
    final rW  = _get(pose, PoseLandmarkType.rightWrist);
    final lH  = _get(pose, PoseLandmarkType.leftHip);
    final rH  = _get(pose, PoseLandmarkType.rightHip);

    if (lSh == null || lE == null || lW == null ||
        rSh == null || rE == null || rW == null ||
        lH == null  || rH == null) return PoseFeedback.ready;
    if (!_vis(lE) || !_vis(rE)) return PoseFeedback.ready;

    // Not pressing yet — wrists still below shoulder level
    if (lW.y > lSh.y && rW.y > rSh.y) return PoseFeedback.ready;

    final lEA = _ang(lSh, lE, lW);
    final rEA = _ang(rSh, rE, rW);
    if (lEA < 140 || rEA < 140) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Extend arms fully');
    }

    final torsoLean = _torsoLeanDeg(lSh, rSh, lH, rH);
    if (torsoLean > 15) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'No excessive back arch');
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkBicepCurl(Pose pose) {
    final lSh = _get(pose, PoseLandmarkType.leftShoulder);
    final lE  = _get(pose, PoseLandmarkType.leftElbow);
    final lW  = _get(pose, PoseLandmarkType.leftWrist);
    final rSh = _get(pose, PoseLandmarkType.rightShoulder);
    final rE  = _get(pose, PoseLandmarkType.rightElbow);
    final rW  = _get(pose, PoseLandmarkType.rightWrist);

    if (lSh == null || lE == null || lW == null ||
        rSh == null || rE == null || rW == null) return PoseFeedback.ready;
    if (!_vis(lE) || !_vis(rE)) return PoseFeedback.ready;

    final lEA = _ang(lSh, lE, lW);
    final rEA = _ang(rSh, rE, rW);

    // ── Engagement: at least one elbow must be actively bending ─────────────
    // Arms fully straight (hanging) = not curling yet.
    if (lEA > 160 && rEA > 160) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Start curling — bend your elbows',
      );
    }

    // ── Elbow drift: elbows must stay pinned to the sides ───────────────────
    final shWidth = (lSh.x - rSh.x).abs();
    final threshold = shWidth * 0.55;
    if ((lE.x - lSh.x).abs() > threshold || (rE.x - rSh.x).abs() > threshold) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Keep elbows at your sides');
    }

    // ── Top of curl: wrists above elbows → check full contraction ───────────
    if (lW.y < lE.y && rW.y < rE.y) {
      if (lEA > 70 || rEA > 70) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Curl all the way up');
      }
    }

    // ── Bottom of curl: wrists below elbows → check full extension ──────────
    if (lW.y > lE.y && rW.y > rE.y) {
      if (lEA < 145 || rEA < 145) {
        return const PoseFeedback(level: FeedbackLevel.warn, message: 'Fully extend arms at the bottom');
      }
    }

    return PoseFeedback.good;
  }

  static PoseFeedback _checkPullUp(Pose pose) {
    final lSh = _get(pose, PoseLandmarkType.leftShoulder);
    final rSh = _get(pose, PoseLandmarkType.rightShoulder);
    final lE  = _get(pose, PoseLandmarkType.leftElbow);
    final lW  = _get(pose, PoseLandmarkType.leftWrist);
    final rW  = _get(pose, PoseLandmarkType.rightWrist);
    final lH  = _get(pose, PoseLandmarkType.leftHip);

    if (lSh == null || rSh == null || lE == null ||
        lW == null  || rW == null  || lH == null) {
      return PoseFeedback.ready;
    }
    if (!_vis(lE) || !_vis(lSh)) return PoseFeedback.ready;

    // ── Engagement: wrists must be at or above shoulder level (hanging) ─────
    // In image coords y increases downward; wrist above shoulder → wrist.y < shoulder.y.
    if (lW.y > lSh.y && rW.y > rSh.y) {
      return const PoseFeedback(
        level: FeedbackLevel.none,
        message: 'Hang from the bar to start',
      );
    }

    // Body swing: shoulder should stay roughly over hip.
    final shWidth  = (lSh.x - rSh.x).abs();
    final bodyLean = (lSh.x - lH.x).abs();
    if (bodyLean > shWidth * 1.2) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Stop swinging — stay vertical');
    }

    // Dead hang: elbow fully extended at the bottom.
    final elbowAngle = _ang(lSh, lE, lW);
    if (lW.y > lE.y && elbowAngle < 150) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Fully extend arms at the bottom');
    }

    // At the top: elbow should be well bent (chin above bar).
    if (lW.y < lSh.y && elbowAngle > 100) {
      return const PoseFeedback(level: FeedbackLevel.warn, message: 'Pull chin above the bar');
    }

    return PoseFeedback.good;
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  /// Angle at vertex [b] formed by segments a→b and c→b, in degrees.
  static double _ang(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ax = a.x - b.x, ay = a.y - b.y;
    final cx = c.x - b.x, cy = c.y - b.y;
    final dot = ax * cx + ay * cy;
    final mA = sqrt(ax * ax + ay * ay);
    final mC = sqrt(cx * cx + cy * cy);
    if (mA < 1e-6 || mC < 1e-6) return 0;
    return acos((dot / (mA * mC)).clamp(-1.0, 1.0)) * 180 / pi;
  }

  /// Torso lean in degrees from vertical (0 = perfectly upright).
  static double _torsoLeanDeg(
    PoseLandmark lSh, PoseLandmark rSh,
    PoseLandmark lH,  PoseLandmark rH,
  ) {
    final sMidX = (lSh.x + rSh.x) / 2;
    final sMidY = (lSh.y + rSh.y) / 2;
    final hMidX = (lH.x  + rH.x)  / 2;
    final hMidY = (lH.y  + rH.y)  / 2;
    return atan2((sMidX - hMidX).abs(), (hMidY - sMidY).abs()) * 180 / pi;
  }

  static bool _vis(PoseLandmark lm) => lm.likelihood > 0.45;

  static PoseLandmark? _get(Pose pose, PoseLandmarkType t) =>
      pose.landmarks[t];
}

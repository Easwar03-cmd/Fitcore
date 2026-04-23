enum FeedbackLevel { none, good, warn, error }

class PoseFeedback {
  const PoseFeedback({required this.level, required this.message});

  final FeedbackLevel level;
  final String message;

  /// No person visible in frame.
  static const noPose = PoseFeedback(
    level: FeedbackLevel.none,
    message: 'Step into frame',
  );

  /// Person detected but not yet in exercise position.
  static const ready = PoseFeedback(
    level: FeedbackLevel.none,
    message: 'Get into position',
  );

  static const good = PoseFeedback(
    level: FeedbackLevel.good,
    message: 'Great form!',
  );
}

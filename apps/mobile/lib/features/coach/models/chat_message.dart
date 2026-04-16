enum MessageRole { user, coach }

class ChatMessage {
  final String id; // uuid
  final MessageRole role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
  });

  /// Serialises to the shape expected by the backend history array.
  /// `coach` maps to `'assistant'` because the Claude API uses that term.
  Map<String, dynamic> toJson() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      };
}

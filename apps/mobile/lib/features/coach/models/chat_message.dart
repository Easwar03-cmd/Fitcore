enum MessageRole { user, coach }

class ChatMessage {
  final String id; // uuid
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  /// Local-only messages (e.g. the greeting) are shown in the UI but never
  /// sent to the backend as conversation history.
  final bool isLocal;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isLocal = false,
  });

  /// Deserialises from the local storage format (includes all fields).
  factory ChatMessage.fromStorageJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] == 'user' ? MessageRole.user : MessageRole.coach,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isLocal: json['isLocal'] as bool? ?? false,
      );

  /// Serialises to local storage format (full fidelity).
  Map<String, dynamic> toStorageJson() => {
        'id': id,
        'role': role == MessageRole.user ? 'user' : 'coach',
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isLocal': isLocal,
      };

  /// Serialises to the shape expected by the backend history array.
  /// `coach` maps to `'assistant'` because the Gemini API uses that term.
  Map<String, dynamic> toJson() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': text,
      };
}

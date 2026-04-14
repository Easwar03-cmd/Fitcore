import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final coachServiceProvider = Provider<CoachService>(
  (ref) => CoachService(ref.read(apiClientProvider)),
);

class CoachMessage {
  const CoachMessage({required this.role, required this.content});

  final String role; // 'user' | 'assistant'
  final String content;
}

/// Sends messages to the AI coach via the backend /api/v1/ai/* routes.
/// The API key never leaves the backend — see CLAUDE.md pitfalls section.
class CoachService {
  CoachService(this._apiClient);

  // ignore: unused_field — will be used when the endpoint is implemented
  final ApiClient _apiClient;

  Future<String> sendMessage({
    required String message,
    required List<CoachMessage> history,
  }) async {
    // TODO: POST /api/v1/ai/coach with message + history
    throw UnimplementedError('CoachService.sendMessage not yet implemented');
  }
}

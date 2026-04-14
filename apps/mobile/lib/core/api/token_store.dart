import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory access token. Cleared on app restart.
/// The refresh token lives only in flutter_secure_storage.
final accessTokenProvider = StateProvider<String?>((ref) => null);

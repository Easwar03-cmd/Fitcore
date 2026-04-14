/// Typed response envelope matching the backend shape:
/// Success: { success: true, data: T, meta?: {...} }
/// Error:   { success: false, error: { code, message, details? } }
class ApiResponse<T> {
  const ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.meta,
  });

  final bool success;
  final T? data;
  final ApiError? error;
  final ApiMeta? meta;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) {
    if (json['success'] == true) {
      return ApiResponse._(
        success: true,
        data: fromJsonT(json['data']),
        meta: json['meta'] != null ? ApiMeta.fromJson(json['meta'] as Map<String, dynamic>) : null,
      );
    } else {
      return ApiResponse._(
        success: false,
        error: ApiError.fromJson(json['error'] as Map<String, dynamic>),
      );
    }
  }
}

class ApiError {
  const ApiError({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
        code: json['code'] as String,
        message: json['message'] as String,
        details: json['details'],
      );
}

class ApiMeta {
  const ApiMeta({this.page, this.total, this.cursor});

  final int? page;
  final int? total;
  final String? cursor;

  factory ApiMeta.fromJson(Map<String, dynamic> json) => ApiMeta(
        page: json['page'] as int?,
        total: json['total'] as int?,
        cursor: json['cursor'] as String?,
      );
}

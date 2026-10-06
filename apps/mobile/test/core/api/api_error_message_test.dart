import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/core/api/api_response.dart';

DioException _dioWith({int? status, Object? body}) {
  final req = RequestOptions(path: '/ai/coach');
  return DioException(
    requestOptions: req,
    response: status == null
        ? null
        : Response<Object?>(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  group('apiErrorMessage', () {
    test('uses the server error message when present', () {
      final e = _dioWith(status: 503, body: {
        'success': false,
        'error': {
          'code': 'AI_UNAVAILABLE',
          'message': 'AI features are temporarily unavailable. Please try again later.',
        },
      });
      expect(apiErrorMessage(e),
          'AI features are temporarily unavailable. Please try again later.');
    });

    test('reports a connection problem when there is no response', () {
      expect(apiErrorMessage(_dioWith()),
          'No connection. Check your internet and try again.');
    });

    test('falls back for unexpected bodies and non-Dio errors', () {
      expect(apiErrorMessage(_dioWith(status: 500, body: 'oops')),
          'Something went wrong. Please try again.');
      expect(apiErrorMessage(const FormatException('bad json')),
          'Something went wrong. Please try again.');
    });
  });
}

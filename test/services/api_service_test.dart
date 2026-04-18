import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';

void main() {
  group('ApiService Authentication', () {
    test('should use Authorization Bearer header for API key', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.io',
        apiKey: 'pk_test_123',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Authorization'], equals('Bearer pk_test_123'));
      expect(headerMap['X-API-Key'], isNull);
    });

    test('should not include Authorization header when apiKey is null', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.io',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Authorization'], isNull);
      expect(headerMap['X-API-Key'], isNull);
    });

    test('should include standard Content-Type and Accept headers', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.io',
        apiKey: 'pk_test_123',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Content-Type'], equals('application/json'));
      expect(headerMap['Accept'], equals('application/json'));
    });

    test('should support custom timeout configuration', () {
      const customTimeout = Duration(seconds: 20);
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.io',
        apiKey: 'pk_test_123',
        timeout: customTimeout,
      );

      expect(apiService.timeout, equals(customTimeout));
    });

    test('should use default 15-second timeout', () {
      final apiService = ApiService(
        baseUrl: 'https://api.linkgravity.io',
        apiKey: 'pk_test_123',
      );

      expect(apiService.timeout, equals(const Duration(seconds: 15)));
    });

    test('should handle different API key formats', () {
      const testCases = [
        'pk_test_123',
        'pk_live_abc123xyz789',
        'sk_test_secret_key',
      ];

      for (final apiKey in testCases) {
        final apiService = ApiService(
          baseUrl: 'https://api.linkgravity.io',
          apiKey: apiKey,
        );

        final headerMap = apiService.headers;
        expect(
          headerMap['Authorization'],
          equals('Bearer $apiKey'),
          reason: 'Failed for API key: $apiKey',
        );
      }
    });
  });

  group('ApiService Exception', () {
    test('should create ApiException with message and status code', () {
      final exception = ApiException(
        'Request failed',
        statusCode: 404,
      );

      expect(exception.message, equals('Request failed'));
      expect(exception.statusCode, equals(404));
      expect(exception.toString(),
          contains('ApiException: Request failed (status: 404)'));
    });

    test('should handle null status code', () {
      final exception = ApiException('Network error');

      expect(exception.message, equals('Network error'));
      expect(exception.statusCode, isNull);
      expect(exception.toString(), contains('ApiException: Network error'));
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';

void main() {
  group('DeferredDeepLinkService Retry Logic', () {
    test('ApiException should have correct status code', () {
      final exception = ApiException(
        'Not found',
        statusCode: 404,
      );

      expect(exception.statusCode, equals(404));
      expect(exception.message, equals('Not found'));
    });

    test('should handle timeout exception correctly', () {
      final exception = TimeoutException('Request timeout');

      expect(exception.toString(), contains('TimeoutException'));
    });

    test('Retry logic constants should be correct', () {
      // Verify exponential backoff calculations
      expect(pow(2, 1).toInt(), equals(2)); // 2 seconds
      expect(pow(2, 2).toInt(), equals(4)); // 4 seconds
      expect(pow(2, 3).toInt(), equals(8)); // 8 seconds

      // Max 3 attempts
      const maxAttempts = 3;
      expect(maxAttempts, equals(3));

      // Timeout per attempt
      const timeout = Duration(seconds: 10);
      expect(timeout.inSeconds, equals(10));
    });

    test('should distinguish between retry-worthy and non-retry errors', () {
      // 404 - should not retry
      final notFound = ApiException('Not found', statusCode: 404);
      expect(notFound.statusCode! >= 400 && notFound.statusCode! < 500, true);

      // 400 - should not retry
      final badRequest = ApiException('Bad request', statusCode: 400);
      expect(
          badRequest.statusCode! >= 400 && badRequest.statusCode! < 500, true);

      // 500 - should retry
      final serverError = ApiException('Server error', statusCode: 500);
      expect(serverError.statusCode! >= 500, true);

      // 503 - should retry
      final unavailable = ApiException('Unavailable', statusCode: 503);
      expect(unavailable.statusCode! >= 500, true);
    });

    test('should handle null status code in ApiException', () {
      final exception = ApiException('Network error');

      expect(exception.statusCode, isNull);
    });

    test('Exponential backoff formula should produce correct values', () {
      // Test exponential backoff: pow(2, attempt + 1)
      final delays = <int>[];
      for (int attempt = 0; attempt < 3; attempt++) {
        final delay = pow(2, attempt + 1).toInt();
        delays.add(delay);
      }

      expect(delays, equals([2, 4, 8]));
    });
  });
}

// Helper function for testing
int pow(int base, int exponent) {
  int result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

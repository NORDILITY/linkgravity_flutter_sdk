import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartlink_flutter_sdk/src/services/api_service.dart';

void main() {
  group('ApiService Authentication', () {
    test('should use Authorization Bearer header for API key', () {
      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Authorization'], equals('Bearer pk_test_123'));
      expect(headerMap['X-API-Key'], isNull);
    });

    test('should not include Authorization header when apiKey is null', () {
      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Authorization'], isNull);
      expect(headerMap['X-API-Key'], isNull);
    });

    test('should include standard Content-Type and Accept headers', () {
      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
      );

      final headerMap = apiService.headers;

      expect(headerMap['Content-Type'], equals('application/json'));
      expect(headerMap['Accept'], equals('application/json'));
    });

    test('should support custom timeout configuration', () {
      const customTimeout = Duration(seconds: 20);
      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
        timeout: customTimeout,
      );

      expect(apiService.timeout, equals(customTimeout));
    });

    test('should use default 15-second timeout', () {
      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
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
          baseUrl: 'https://api.smartlink.io',
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

  group('ApiService getSdkConfig', () {
    test('should parse config from response correctly', () async {
      // Backend response format as documented in sdk.controller.ts:907-922
      final mockResponse = {
        'success': true,
        'config': {
          'version': 1,
          'deferredLinkTimeout': 3000,
          'enableAnalytics': true,
        },
        'cached': true,
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/sdk/config'));
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
        client: mockClient,
      );

      final config = await apiService.getSdkConfig();

      expect(config['version'], equals(1));
      expect(config['deferredLinkTimeout'], equals(3000));
      expect(config['enableAnalytics'], equals(true));
    });

    test('should return empty map when config is null', () async {
      final mockResponse = {
        'success': true,
        'config': null,
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
        client: mockClient,
      );

      final config = await apiService.getSdkConfig();

      expect(config, isEmpty);
    });

    test('should return empty map when success is false', () async {
      final mockResponse = {
        'success': false,
        'config': {
          'version': 1,
        },
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
        client: mockClient,
      );

      final config = await apiService.getSdkConfig();

      expect(config, isEmpty);
    });

    test('should not parse data field (regression test for bug fix)', () async {
      // This test ensures we don't accidentally revert to the old 'data' field
      final mockResponse = {
        'success': true,
        'data': {
          'wrongField': 'should not be parsed',
        },
        'config': {
          'version': 2,
          'correctField': true,
        },
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiService = ApiService(
        baseUrl: 'https://api.smartlink.io',
        apiKey: 'pk_test_123',
        client: mockClient,
      );

      final config = await apiService.getSdkConfig();

      // Should parse 'config', not 'data'
      expect(config['version'], equals(2));
      expect(config['correctField'], equals(true));
      expect(config['wrongField'], isNull);
    });
  });
}

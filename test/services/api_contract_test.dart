/// The wire contract with the backend: exact paths, and the field names in a create.
///
/// Nothing pinned either before. The suite passed while `createLink` posted to
/// `/api/sdk/links` — a path the backend does not mount, so it 404'd in every released
/// version — and while the body it sent used field names the backend rejects. Neither could
/// fail a test, because the existing `api_service_test.dart` only covers headers and
/// timeouts.
///
/// A mocked client is enough: the failures were never about the network, they were about
/// asking for the wrong thing. Anything asserted here has a counterpart in
/// `backend/src/routes/sdk.routes.ts` or `createLinkSchema`; change one and this should fail.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkgravity_flutter_sdk/src/models/analytics_event.dart';
import 'package:linkgravity_flutter_sdk/src/models/link_params.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';

/// Captures the one request the call makes, and answers with something parseable.
class _Captured {
  late Uri uri;
  late String method;
  Map<String, dynamic> body = {};
}

ApiService _service(_Captured seen, {Object? responseBody}) {
  final client = MockClient((request) async {
    seen.uri = request.url;
    seen.method = request.method;
    if (request.body.isNotEmpty) {
      seen.body = jsonDecode(request.body) as Map<String, dynamic>;
    }
    return http.Response(
      jsonEncode(responseBody ?? {'success': true, 'data': {}}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  return ApiService(
    baseUrl: 'https://api.example.test',
    apiKey: 'pk_live_contract_test',
    client: client,
  );
}

void main() {
  group('paths the backend actually mounts', () {
    test('createDynamicLink posts to /api/v1/sdk/links', () async {
      final seen = _Captured();
      // The /v1 is the whole point: /api/sdk/links is not routed and returned 404 in every
      // released version, which is the bug this test exists to prevent recurring.
      await _service(seen, responseBody: {
        'link': {'id': 'l1', 'shortCode': 'abc', 'destination': 'https://example.com', 'createdAt': '2026-01-01T00:00:00Z'}
      }).createDynamicLink(LinkParams(longUrl: 'https://example.com'));

      expect(seen.uri.path, '/api/v1/sdk/links');
      expect(seen.method, 'POST');
    });

    test('resolveShortCode reads /api/v1/sdk/resolve/:code', () async {
      final seen = _Captured();
      await _service(seen, responseBody: {'success': true, 'route': '/x'})
          .resolveShortCode('abc123');

      expect(seen.uri.path, '/api/v1/sdk/resolve/abc123');
    });
  });

  group('createLink body matches createLinkSchema', () {
    late _Captured seen;

    setUp(() async {
      seen = _Captured();
      await _service(seen, responseBody: {
        'link': {'id': 'l1', 'shortCode': 'abc', 'destination': 'https://example.com/p/1', 'createdAt': '2026-01-01T00:00:00Z'}
      }).createDynamicLink(
        LinkParams(
          longUrl: 'https://example.com/p/1',
          title: 'Product',
          shortCode: 'promo',
          deepLinkConfig: DeepLinkConfig(
            deepLinkPath: '/product/1',
            fallbackUrl: 'https://example.com/fallback',
          ),
          utmParams: const {'source': 'app', 'campaign': 'spring'},
        ),
      );
    });

    test('sends destination, never longUrl', () {
      // The backend requires `destination`; `longUrl` is this package's own vocabulary and
      // is stripped server-side, so sending it produced a 400 for a missing field.
      expect(seen.body['destination'], 'https://example.com/p/1');
      expect(seen.body.containsKey('longUrl'), isFalse);
    });

    test('flattens deepLinkConfig into the fields the schema names', () {
      expect(seen.body['path'], '/product/1');
      expect(seen.body['fallbackUrl'], 'https://example.com/fallback');
      expect(seen.body.containsKey('deepLinkConfig'), isFalse);
    });

    test('spreads utmParams into their own columns', () {
      expect(seen.body['source'], 'app');
      expect(seen.body['campaign'], 'spring');
      expect(seen.body.containsKey('utmParams'), isFalse);
    });

    test('omits projectId — the backend resolves it from the API key', () {
      // The SDK cannot know it, and a client-supplied project id would be a way to write
      // into someone else's project.
      expect(seen.body.containsKey('projectId'), isFalse);
    });

    test('passes the optional fields the schema does accept', () {
      expect(seen.body['title'], 'Product');
      expect(seen.body['shortCode'], 'promo');
    });
  });

  group('authentication', () {
    test('sends the key as a Bearer token', () {
      final headers = ApiService(baseUrl: 'https://api.example.test', apiKey: 'pk_x').headers;
      expect(headers['Authorization'], 'Bearer pk_x');
    });
  });

  group('analytics ingest — the half that never reached the dashboard', () {
    test('sendBatch posts to /api/v1/sdk/events', () async {
      final seen = _Captured();
      await _service(seen).sendBatch([
        AnalyticsEvent(
          id: 'e1',
          name: 'purchase',
          data: const {'amount': 9.99},
          timestamp: DateTime.utc(2026, 9, 19, 12),
        ),
      ]);

      expect(seen.uri.path, '/api/v1/sdk/events');
      expect(seen.method, 'POST');
    });

    test('sendBatch carries the attribution the backend scopes on', () async {
      // Without deviceId or linkId every event lands unattributed. That is precisely what
      // the batch used to do, and why the Events chart read zero for everyone.
      final seen = _Captured();
      await _service(seen).sendBatch(
        [
          AnalyticsEvent(
            id: 'e1',
            name: 'purchase',
            data: const {},
            timestamp: DateTime.utc(2026, 9, 19, 12),
            userId: 'app-user-7',
          ),
        ],
        deviceId: 'device-1',
        linkId: 'link-1',
      );

      expect(seen.body['deviceId'], 'device-1');
      expect(seen.body['linkId'], 'link-1');
      // setUserId was stored on every event and then dropped here.
      expect(seen.body['userId'], 'app-user-7');
    });

    test('sendBatch renames name → type, data → properties', () async {
      final seen = _Captured();
      await _service(seen).sendBatch([
        AnalyticsEvent(
          id: 'e1',
          name: 'purchase',
          data: const {'amount': 9.99},
          timestamp: DateTime.utc(2026, 9, 19, 12),
        ),
      ]);

      final event = (seen.body['events'] as List).first as Map<String, dynamic>;
      expect(event['type'], 'purchase');
      expect((event['properties'] as Map)['amount'], 9.99);
      expect(event.containsKey('name'), isFalse);
    });

    test('trackConversion sends transactionId so a retry cannot double-count', () async {
      final seen = _Captured();
      await _service(seen).trackConversion(
        type: 'purchase',
        revenue: 99,
        transactionId: 'order-1',
        deviceId: 'device-1',
      );

      expect(seen.uri.path, '/api/v1/sdk/conversions');
      expect(seen.body['transactionId'], 'order-1');
      expect(seen.body['deviceId'], 'device-1');
    });

    test('trackConversion no longer sends eventId', () async {
      // The backend dropped the column: no SDK path could ever fill it.
      final seen = _Captured();
      await _service(seen).trackConversion(type: 'signup', revenue: 0);

      expect(seen.body.containsKey('eventId'), isFalse);
    });
  });
}

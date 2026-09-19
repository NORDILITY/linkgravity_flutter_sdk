/// What a batch actually carries by the time it leaves the device.
///
/// These assert the two fields the backend needs and that nothing on the Dart side used
/// to supply. Both failed silently: the events were accepted, stored, and then filtered
/// out or filed as Unknown, with no error on either side to notice.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkgravity_flutter_sdk/src/services/analytics_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Captured {
  Uri? uri;
  Map<String, dynamic> body = {};
  int calls = 0;
}

AnalyticsService _service(_Captured seen, StorageService storage) {
  final client = MockClient((request) async {
    seen.calls++;
    seen.uri = request.url;
    if (request.body.isNotEmpty) {
      seen.body = jsonDecode(request.body) as Map<String, dynamic>;
    }
    return http.Response(
      jsonEncode({'success': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  return AnalyticsService(
    api: ApiService(
      baseUrl: 'https://api.example.test',
      apiKey: 'pk_live_analytics_test',
      client: client,
    ),
    storage: storage,
  );
}

Map<String, dynamic> _firstEvent(_Captured seen) =>
    (seen.body['events'] as List).first as Map<String, dynamic>;

void main() {
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  test('attaches platform to an event the app tracks itself', () async {
    // Only the SDK's own events used to set this, so every event a customer tracked was
    // filed as Unknown and the platform breakdown described nothing.
    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'ios';

    await analytics.trackEvent('purchase', {'amount': 9.99});
    await analytics.flush();

    expect((_firstEvent(seen)['properties'] as Map)['platform'], 'ios');
  });

  test('lets an explicit platform in properties win', () async {
    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'ios';

    await analytics.trackEvent('purchase', {'platform': 'web'});
    await analytics.flush();

    expect((_firstEvent(seen)['properties'] as Map)['platform'], 'web');
  });

  test('sends the device id so the backend can attribute the batch', () async {
    await storage.saveDeviceId('device-abc');

    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'android';

    await analytics.trackEvent('screen_view');
    await analytics.flush();

    expect(seen.uri?.path, '/api/v1/sdk/events');
    expect(seen.body['deviceId'], 'device-abc');
  });

  test('retried offline events carry attribution too', () async {
    // The path that is hardest to notice. Events that failed once and were queued used to
    // be re-sent with no device id at all, so anything that ever hit a bad connection
    // arrived unattributed — the exact failure this release fixes, surviving in the retry.
    await storage.saveDeviceId('device-xyz');
    await storage.saveFailedEvents([]);

    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'ios';

    // Queue one event through the normal path, then fail it into the offline queue by
    // going through flush with a client that rejects.
    final failing = AnalyticsService(
      api: ApiService(
        baseUrl: 'https://api.example.test',
        apiKey: 'pk_live_analytics_test',
        client: MockClient((_) async => http.Response('nope', 500)),
      ),
      storage: storage,
    );
    await failing.trackEvent('purchase');
    await failing.flush();

    final queued = await storage.getFailedEvents();
    expect(queued, isNotEmpty, reason: 'the failed batch should have been stored');

    // Now retry through a working client.
    await analytics.retryFailedEventsForTest();

    expect(seen.calls, greaterThan(0), reason: 'the retry should have sent something');
    expect(seen.body['deviceId'], 'device-xyz');
  });

  test('a revenue event flushes immediately, without waiting for the batch', () async {
    // Telemetry waits for 20 events or 30 seconds. Money does not — but it goes through the
    // queue rather than around it, so it survives the app being killed and cannot overtake
    // the add_to_cart still sitting in the batch.
    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'ios';

    await analytics.trackEvent('screen_view');
    expect(seen.calls, 0, reason: 'telemetry should still be waiting');

    await analytics.trackEvent('purchase', {'sku': 'x'}, 29.99, 'EUR', 'order-9');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(seen.calls, 1);
    final events = seen.body['events'] as List;
    expect(events, hasLength(2), reason: 'the queued screen_view should ride along');

    final purchase = events[1] as Map<String, dynamic>;
    expect(purchase['revenue'], 29.99);
    expect(purchase['currency'], 'EUR');
    expect(purchase['transactionId'], 'order-9');
  });

  test('telemetry carries no revenue or currency', () async {
    final seen = _Captured();
    final analytics = _service(seen, storage)..platform = 'ios';

    await analytics.trackEvent('screen_view');
    await analytics.flush();

    final event = (seen.body['events'] as List).first as Map<String, dynamic>;
    expect(event.containsKey('revenue'), isFalse);
    expect(event.containsKey('currency'), isFalse);
  });
}

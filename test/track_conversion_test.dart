/// `trackConversion` is now a thin wrapper over `trackEvent` that sets the monetary fields
/// and flushes immediately. There is no conversions endpoint behind it any more — a purchase
/// is an event that carries money.
///
/// The one rule it enforces on its own is the currency: it used to default to 'USD', so an
/// app selling in euros that never set it filed every sale as dollars, permanently and with
/// nothing to indicate it. That is the only failure here that corrupts stored data rather
/// than a display.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkgravity_flutter_sdk/src/linkgravity_client.dart';
import 'package:linkgravity_flutter_sdk/src/linkgravity_config.dart';
import 'package:linkgravity_flutter_sdk/src/services/analytics_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/deep_link_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/fingerprint_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Captured {
  final List<Map<String, dynamic>> bodies = [];
  List<Map<String, dynamic>> get events =>
      bodies.expand((b) => (b['events'] as List).cast<Map<String, dynamic>>()).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Captured seen;
  late LinkGravityClient client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    seen = _Captured();

    final httpClient = MockClient((request) async {
      if (request.body.isNotEmpty) {
        seen.bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(
      baseUrl: 'https://api.example.test',
      apiKey: 'pk_live_conversion_test',
      client: httpClient,
    );
    final storage = StorageService();

    client = LinkGravityClient.forTesting(
      baseUrl: 'https://api.example.test',
      apiKey: 'pk_live_conversion_test',
      config: LinkGravityConfig(),
      api: api,
      deepLink: DeepLinkService(),
      fingerprint: FingerprintService(),
      storage: storage,
      analytics: AnalyticsService(api: api, storage: storage),
    );
  });

  test('sends a purchase as an event carrying money', () async {
    final ok = await client.trackConversion(
      type: 'purchase',
      revenue: 29.99,
      currency: 'EUR',
      transactionId: 'order-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(ok, isTrue);
    expect(seen.events, hasLength(1));

    final event = seen.events.single;
    expect(event['type'], 'purchase');
    expect(event['revenue'], 29.99);
    expect(event['currency'], 'EUR');
    expect(event['transactionId'], 'order-1');
  });

  test('refuses revenue without a currency, and sends nothing', () async {
    final ok = await client.trackConversion(type: 'purchase', revenue: 29.99);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(ok, isFalse);
    expect(seen.bodies, isEmpty, reason: 'a guess would be stored as fact — send nothing');
  });

  test('allows a non-monetary conversion with no currency', () async {
    // A signup is a real conversion with no money in it. It must not be forced to invent
    // either a revenue of 0 or a currency to carry it.
    final ok = await client.trackConversion(type: 'signup');
    await client.flushEvents();

    expect(ok, isTrue);
    final event = seen.events.single;
    expect(event['type'], 'signup');
    expect(event.containsKey('revenue'), isFalse);
    expect(event.containsKey('currency'), isFalse);
  });
}

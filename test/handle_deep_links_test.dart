import 'dart:async';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeepLinkService deepLinkService;
  late LinkGravityClient client;

  setUp(() {
    LinkGravityClient.resetForTesting();
    deepLinkService = DeepLinkService();

    // New resolve payload shape: `route` is a plain path (e.g. "/details"),
    // NOT a full URI like "schema://schema/details". Destination + UTM are
    // returned as sibling fields.
    final mockHttpClient = MockClient((request) async {
      if (request.url.path.contains('/api/v1/sdk/resolve/details')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'shortCode': 'details',
            'route': '/details',
            'destination': 'https://example.com',
            'utm': {
              'campaign': null,
              'source': null,
              'medium': null,
              'content': null,
              'term': null,
            },
          }),
          200,
        );
      }
      if (request.url.path.contains('/api/v1/sdk/resolve/child')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'shortCode': 'child',
            'route': '/parent/child',
            'destination': 'https://example.com/parent/child',
            'utm': {
              'campaign': null,
              'source': null,
              'medium': null,
              'content': null,
              'term': null,
            },
          }),
          200,
        );
      }
      if (request.url.path.contains('/api/v1/sdk/resolve/promo')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'shortCode': 'promo',
            'route': '/promo',
            'destination': 'https://example.com/promo',
            'utm': {
              'campaign': 'spring_sale',
              'source': 'email',
              'medium': 'newsletter',
              'content': null,
              'term': null,
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({'success': false, 'message': 'Not found'}),
        404,
      );
    });

    final apiService = ApiService(
      baseUrl: 'https://test.linkgravity.io',
      apiKey: 'test-key',
      client: mockHttpClient,
    );

    final storage = StorageService();
    final analytics = AnalyticsService(
      api: apiService,
      storage: storage,
      enabled: false,
      offlineQueueEnabled: false,
    );

    client = LinkGravityClient.forTesting(
      baseUrl: 'https://test.linkgravity.io',
      apiKey: 'test-key',
      config: LinkGravityConfig(enableAnalytics: false),
      api: apiService,
      deepLink: deepLinkService,
      fingerprint: FingerprintService(),
      storage: storage,
      analytics: analytics,
    );
  });

  tearDown(() {
    deepLinkService.dispose();
    LinkGravityClient.resetForTesting();
  });

  group('handleDeepLinks', () {
    test('/details resolves to /details', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      client.processDeepLink('/details');

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/details');
    });

    test('falls back to direct path when API resolution fails', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      // Unknown shortcode — mock returns 404, SDK falls back to using the
      // incoming path verbatim.
      client.processDeepLink('/unknown-page');

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/unknown-page');
    });

    test('/parent/child resolves to /parent/child', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      client.processDeepLink('/parent/child');

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/parent/child');
    });

    test('https://example.com/details resolves to /details', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      client.processDeepLink('https://example.com/details');

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/details');
    });

    test('already-resolved link navigates directly without API call', () async {
      final completer = Completer<String>();
      var apiCallCount = 0;

      // Create a client with a tracked mock to detect any API calls
      final trackedHttpClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          jsonEncode({'success': true, 'route': '/details'}),
          200,
        );
      });

      final trackedApiService = ApiService(
        baseUrl: 'https://test.linkgravity.io',
        apiKey: 'test-key',
        client: trackedHttpClient,
      );

      final storage = StorageService();
      final trackedClient = LinkGravityClient.forTesting(
        baseUrl: 'https://test.linkgravity.io',
        apiKey: 'test-key',
        config: LinkGravityConfig(enableAnalytics: false),
        api: trackedApiService,
        deepLink: deepLinkService,
        fingerprint: FingerprintService(),
        storage: storage,
        analytics: AnalyticsService(
          api: trackedApiService,
          storage: storage,
          enabled: false,
          offlineQueueEnabled: false,
        ),
      );

      trackedClient.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      // Pre-resolved link (e.g. from deferred deep link match) bypasses
      // the /resolve call and goes straight to navigation.
      trackedClient.processDeepLink('/details', isResolved: true);

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/details');
      expect(apiCallCount, 0,
          reason: 'No API call should be made for already-resolved links');
    });

    test('incoming query params are merged onto the resolved plain-path route',
        () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      // Incoming link carries extra query params. Backend returns route="/details"
      // (plain path, no query string). The SDK must append the incoming params
      // to the resolved route verbatim.
      client
          .processDeepLink('https://example.com/details?promo=summer&ref=abc');

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, startsWith('/details?'));
      final navigatedUri = Uri.parse(navigatedPath);
      expect(navigatedUri.path, '/details');
      expect(navigatedUri.queryParameters['promo'], 'summer');
      expect(navigatedUri.queryParameters['ref'], 'abc');
    });

    test('UTM from resolve response is applied via setUTM', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      client.processDeepLink('https://example.com/promo');

      await completer.future.timeout(const Duration(seconds: 5));

      // UTM sibling field in the resolve response should flow to the client's
      // current UTM attribution.
      final utm = client.currentUTM;
      expect(utm, isNotNull);
      expect(utm!.campaign, 'spring_sale');
      expect(utm.source, 'email');
      expect(utm.medium, 'newsletter');
    });
  });
}

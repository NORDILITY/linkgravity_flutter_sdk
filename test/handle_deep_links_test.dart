import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkgravity_flutter_sdk/src/linkgravity_client.dart';
import 'package:linkgravity_flutter_sdk/src/linkgravity_config.dart';
import 'package:linkgravity_flutter_sdk/src/models/deep_link_data.dart';
import 'package:linkgravity_flutter_sdk/src/services/api_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/deep_link_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/fingerprint_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/storage_service.dart';
import 'package:linkgravity_flutter_sdk/src/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeepLinkService deepLinkService;
  late LinkGravityClient client;

  setUp(() {
    LinkGravityClient.resetForTesting();
    deepLinkService = DeepLinkService();

    final mockHttpClient = MockClient((request) async {
      if (request.url.path.contains('/api/v1/sdk/resolve/details')) {
        return http.Response(
          jsonEncode({'success': true, 'route': '/details'}),
          200,
        );
      }
      if (request.url.path.contains('/api/v1/sdk/resolve/child')) {
        return http.Response(
          jsonEncode({'success': true, 'route': '/parent/child'}),
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
    test('myapp://details resolves to /details', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      // myapp://details → custom scheme parsing gives path="/details"
      // processLink extracts shortCode "details", API resolves to /details
      final uri = Uri.parse('myapp://details');
      deepLinkService.linkController.add(DeepLinkData.fromUri(uri));

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

      // Use an unknown shortCode that the mock API won't resolve
      final uri = Uri.parse('myapp://unknown-page');
      deepLinkService.linkController.add(DeepLinkData.fromUri(uri));

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/unknown-page');
    });

    test('myapp://parent/child resolves to /parent/child', () async {
      final completer = Completer<String>();

      client.handleDeepLinks(
        onNavigate: (path) {
          if (!completer.isCompleted) completer.complete(path);
        },
      );

      // myapp://parent/child → custom scheme parsing gives path="/parent/child"
      // processLink extracts shortCode "child" (last segment), API resolves to /parent/child
      final uri = Uri.parse('myapp://here_must_be_parent_TODO/child');
      deepLinkService.linkController.add(DeepLinkData.fromUri(uri));

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

      // https://example.com/details → http scheme keeps host, path="/details"
      // processLink extracts shortCode "details", API resolves to /details
      final uri = Uri.parse('https://example.com/details');
      deepLinkService.linkController.add(DeepLinkData.fromUri(uri));

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

      // Simulate a link that was already resolved (e.g. from deferred deep link)
      deepLinkService.linkController.add(DeepLinkData(
        path: '/details',
        params: {},
        scheme: 'myapp',
        isResolved: true,
      ));

      final navigatedPath = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(navigatedPath, '/details');
      expect(apiCallCount, 0, reason: 'No API call should be made for already-resolved links');
    });
  });
}

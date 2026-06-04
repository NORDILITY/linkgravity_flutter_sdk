// Red-phase tests for LGR-40 iOS Universal Link click attribution.
//
// These tests describe the target behavior of `processDeepLink` once the
// SDK threads `source`, `cid`, and `fp` through to `/resolve` and gates
// resolution on `config.linkHosts`. They fail today; they pass once
// `linkgravity_client.dart` and `api_service.dart` are updated.
//
// See design discussion: feature/lgr-40-ios-link-tracking.

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
  late List<Uri> capturedResolveCalls;

  // Builds a client whose /resolve calls are captured into
  // `capturedResolveCalls` and answered with a canned 200.
  LinkGravityClient buildClient({
    List<String> linkHosts = const [],
    String? platformOverride,
  }) {
    capturedResolveCalls = [];

    final mockHttpClient = MockClient((request) async {
      if (request.url.path.contains('/api/v1/sdk/resolve/')) {
        capturedResolveCalls.add(request.url);
        return http.Response(
          jsonEncode({
            'success': true,
            'shortCode': request.url.pathSegments.last,
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
      return http.Response(jsonEncode({'success': false}), 404);
    });

    final api = ApiService(
      baseUrl: 'https://test.linkgravity.io',
      apiKey: 'test-key',
      client: mockHttpClient,
    );
    final storage = StorageService();

    return LinkGravityClient.forTesting(
      baseUrl: 'https://test.linkgravity.io',
      apiKey: 'test-key',
      config: LinkGravityConfig(
        enableAnalytics: false,
        linkHosts: linkHosts,
        platformOverride: platformOverride,
      ),
      api: api,
      deepLink: deepLinkService,
      fingerprint: FingerprintService(),
      storage: storage,
      analytics: AnalyticsService(
        api: api,
        storage: storage,
        enabled: false,
        offlineQueueEnabled: false,
      ),
    );
  }

  Future<String> processAndAwait(
    LinkGravityClient client,
    String link, {
    bool isFromDeferredMatch = false,
  }) async {
    final completer = Completer<String>();
    client.handleDeepLinks(onNavigate: (path) {
      if (!completer.isCompleted) completer.complete(path);
    });
    client.processDeepLink(link, isFromDeferredMatch: isFromDeferredMatch);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  setUp(() {
    LinkGravityClient.resetForTesting();
    deepLinkService = DeepLinkService();
  });

  tearDown(() {
    deepLinkService.dispose();
    LinkGravityClient.resetForTesting();
  });

  group('Pure Universal/App Link (server bypassed)', () {
    test('http link on a configured host sends source and fp, no cid',
        () async {
      // The exact source value depends on Platform.isIOS at runtime. Until a
      // `platformOverride` test hook lands we only assert the shape.
      final client = buildClient(linkHosts: ['lg.example']);

      await processAndAwait(client, 'https://lg.example/abc');

      expect(capturedResolveCalls, hasLength(1));
      final uri = capturedResolveCalls.single;
      expect(uri.pathSegments.last, 'abc');
      expect(
        uri.queryParameters['source'],
        anyOf('ios_universal_link', 'android_app_link'),
      );
      expect(uri.queryParameters['cid'], isNull);
      expect(uri.queryParameters['fp'], isNotNull);
      expect(uri.queryParameters['fp'], isNotEmpty);
    });
  });

  group('Click already counted server-side (lgr_cid present)', () {
    test('http link with ?lgr_cid sends cid and NO source', () async {
      final client = buildClient(linkHosts: ['lg.example']);

      await processAndAwait(client, 'https://lg.example/abc?lgr_cid=ck_123');

      expect(capturedResolveCalls, hasLength(1));
      final uri = capturedResolveCalls.single;
      expect(uri.queryParameters['cid'], 'ck_123');
      expect(uri.queryParameters['source'], isNull);
    });

    test('lgr_cid is stripped before the route is passed to onNavigate',
        () async {
      final client = buildClient(linkHosts: ['lg.example']);

      final navigated = await processAndAwait(
        client,
        'https://lg.example/abc?lgr_cid=ck_123&promo=summer',
      );

      // Backend mock returns route="/details"; SDK appends the (cleaned)
      // incoming query params. lgr_cid must NOT appear in what the host app
      // sees.
      final uri = Uri.parse(navigated);
      expect(uri.queryParameters.containsKey('lgr_cid'), isFalse);
      expect(uri.queryParameters['promo'], 'summer');
    });
  });

  group('Deferred match', () {
    test('isFromDeferredMatch=true sends neither source nor cid', () async {
      final client = buildClient(linkHosts: ['lg.example']);

      await processAndAwait(
        client,
        'https://lg.example/abc',
        isFromDeferredMatch: true,
      );

      expect(capturedResolveCalls, hasLength(1));
      final uri = capturedResolveCalls.single;
      expect(uri.queryParameters['source'], isNull);
      expect(uri.queryParameters['cid'], isNull);
    });
  });

  group('Custom-scheme link', () {
    test('tappicknew:// link does not send source or cid', () async {
      final client = buildClient(linkHosts: ['lg.example']);

      await processAndAwait(client, 'tappicknew://abc');

      expect(capturedResolveCalls, hasLength(1));
      final uri = capturedResolveCalls.single;
      expect(uri.queryParameters['source'], isNull);
      expect(uri.queryParameters['cid'], isNull);
    });
  });

  group('Host gating via config.linkHosts', () {
    test('http link to a host NOT in linkHosts skips /resolve entirely',
        () async {
      final client = buildClient(linkHosts: ['lg.example']);

      final navigated = await processAndAwait(client, 'https://other.com/foo');

      expect(
        capturedResolveCalls,
        isEmpty,
        reason: 'Foreign host should not hit /resolve',
      );
      // Contract: foreign hosts pass straight to onNavigate verbatim; the
      // host app's router decides what to do with them.
      expect(navigated, 'https://other.com/foo');
    });

    test('http link to a host that IS in linkHosts triggers /resolve',
        () async {
      final client = buildClient(linkHosts: ['lg.example', 'short.test']);

      await processAndAwait(client, 'https://short.test/xyz');

      expect(capturedResolveCalls, hasLength(1));
      expect(capturedResolveCalls.single.pathSegments.last, 'xyz');
    });

    test('plain-path link is always resolved (no host to check)', () async {
      final client = buildClient(linkHosts: ['lg.example']);

      await processAndAwait(client, '/details');

      expect(capturedResolveCalls, hasLength(1));
    });

    test(
      'empty linkHosts (default) preserves legacy "resolve every http" behavior',
      () async {
        final client = buildClient(linkHosts: const []);

        await processAndAwait(client, 'https://anything.example/abc');

        expect(capturedResolveCalls, hasLength(1));
      },
    );
  });

  group('Source value by platform', () {
    test('iOS: source=ios_universal_link', () async {
      final client = buildClient(
        linkHosts: ['lg.example'],
        platformOverride: 'ios',
      );

      await processAndAwait(client, 'https://lg.example/abc');

      expect(
        capturedResolveCalls.single.queryParameters['source'],
        'ios_universal_link',
      );
    });

    test('Android: source=android_app_link', () async {
      final client = buildClient(
        linkHosts: ['lg.example'],
        platformOverride: 'android',
      );

      await processAndAwait(client, 'https://lg.example/abc');

      expect(
        capturedResolveCalls.single.queryParameters['source'],
        'android_app_link',
      );
    });
  });
}

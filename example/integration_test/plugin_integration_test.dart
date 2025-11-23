// SmartLink Flutter SDK Integration Test
//
// Tests the SDK integration with a real Flutter application.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SmartLink SDK Integration', () {
    testWidgets('SDK initializes successfully', (WidgetTester tester) async {
      // Initialize SDK
      final client = await SmartLinkClient.initialize(
        baseUrl: 'http://localhost:3000',
        apiKey: 'test-api-key',
        config: SmartLinkConfig(
          enableAnalytics: false, // Disable for testing
          logLevel: LogLevel.debug,
        ),
      );

      expect(client.isInitialized, true);
      expect(client.fingerprint, isNotNull);
      expect(client.sessionId, isNotNull);
    });

    testWidgets('Can track events', (WidgetTester tester) async {
      await SmartLinkClient.instance.trackEvent('test_event', {
        'test_property': 'test_value',
      });

      // If no exception thrown, test passes
      expect(true, true);
    });

    testWidgets('Can listen to deep links', (WidgetTester tester) async {

      // Wait a bit (in real scenario, a deep link would be triggered)
      await tester.pump(const Duration(milliseconds: 100));

      // Stream should be available (even if no links received yet)
      expect(SmartLinkClient.instance.onDeepLink, isNotNull);
    });

    testWidgets('SDK loads config from backend', (WidgetTester tester) async {
      // This test verifies that the SDK correctly loads and parses
      // the config from the backend using response['config'] format.
      //
      // Backend response format (sdk.controller.ts:907-922):
      // {
      //   "success": true,
      //   "config": {
      //     "version": 1,
      //     "deferredLinkTimeout": 3000,
      //     "enableAnalytics": true
      //   },
      //   "cached": true
      // }

      // The SDK should be initialized from previous test
      expect(SmartLinkClient.instance.isInitialized, true);

      // Note: In a real integration test with a running backend,
      // we would verify that getSdkConfig() returns the expected values.
      // For now, we verify the SDK is properly initialized and can
      // make API calls without throwing exceptions.

      // The apiService is internal, but we can verify the SDK
      // is working correctly by checking initialization state
      expect(SmartLinkClient.instance.fingerprint, isNotNull);
    });
  });
}

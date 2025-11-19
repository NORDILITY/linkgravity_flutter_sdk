import 'package:flutter_test/flutter_test.dart';
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';
import 'package:http/http.dart' as http;

// Generate mocks with: flutter pub run build_runner build
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartLink Models', () {
    test('SmartLink fromJson/toJson', () {
      final json = {
        'id': 'link-123',
        'shortCode': 'abc123',
        'shortUrl': 'https://smartlink.io/abc123',
        'longUrl': 'https://example.com/product/123',
        'title': 'Test Link',
        'active': true,
        'createdAt': '2025-11-19T10:00:00.000Z',
      };

      final link = SmartLink.fromJson(json);

      expect(link.id, 'link-123');
      expect(link.shortCode, 'abc123');
      expect(link.shortUrl, 'https://smartlink.io/abc123');
      expect(link.longUrl, 'https://example.com/product/123');
      expect(link.title, 'Test Link');
      expect(link.active, true);

      final serialized = link.toJson();
      expect(serialized['id'], 'link-123');
      expect(serialized['shortCode'], 'abc123');
    });

    test('LinkParams validation', () {
      final validParams = LinkParams(
        longUrl: 'https://example.com/path',
        shortCode: 'test123',
      );
      expect(validParams.validate(), true);

      final invalidUrl = LinkParams(
        longUrl: 'not-a-url',
      );
      expect(invalidUrl.validate(), false);

      final invalidShortCode = LinkParams(
        longUrl: 'https://example.com/path',
        shortCode: 'ab', // Too short
      );
      expect(invalidShortCode.validate(), false);
    });

    test('DeepLinkData fromUri', () {
      final uri = Uri.parse('smartlink://host/product/123?ref=campaign');
      final deepLink = DeepLinkData.fromUri(uri);

      expect(deepLink.scheme, 'smartlink');
      expect(deepLink.path, '/product/123');
      expect(deepLink.params['ref'], 'campaign');
    });
  });

  group('Validators', () {
    test('isValidUrl', () {
      expect(Validators.isValidUrl('https://example.com'), true);
      expect(Validators.isValidUrl('http://test.com/path'), true);
      expect(Validators.isValidUrl('not-a-url'), false);
      expect(Validators.isValidUrl(''), false);
    });

    test('isValidShortCode', () {
      expect(Validators.isValidShortCode('abc123'), true);
      expect(Validators.isValidShortCode('test-code'), true);
      expect(Validators.isValidShortCode('ab'), false); // Too short
      expect(Validators.isValidShortCode('this-is-way-too-long-code'), false); // Too long
      expect(Validators.isValidShortCode('invalid@code'), false); // Invalid chars
    });

    test('isValidDeepLinkPath', () {
      expect(Validators.isValidDeepLinkPath('/product/123'), true);
      expect(Validators.isValidDeepLinkPath('/category/electronics'), true);
      expect(Validators.isValidDeepLinkPath('no-leading-slash'), false);
      expect(Validators.isValidDeepLinkPath('/invalid//double'), false);
    });
  });

  group('SmartLinkConfig', () {
    test('default config', () {
      final config = SmartLinkConfig();

      expect(config.enableAnalytics, true);
      expect(config.enableDeepLinking, true);
      expect(config.enableOfflineQueue, true);
      expect(config.batchSize, 20);
      expect(config.batchTimeout, const Duration(seconds: 30));
      expect(config.logLevel, LogLevel.info);
    });

    test('custom config', () {
      final config = SmartLinkConfig(
        enableAnalytics: false,
        batchSize: 50,
        logLevel: LogLevel.debug,
      );

      expect(config.enableAnalytics, false);
      expect(config.batchSize, 50);
      expect(config.logLevel, LogLevel.debug);
    });

    test('copyWith', () {
      final config1 = SmartLinkConfig();
      final config2 = config1.copyWith(
        enableAnalytics: false,
        batchSize: 100,
      );

      expect(config2.enableAnalytics, false);
      expect(config2.batchSize, 100);
      expect(config2.enableDeepLinking, true); // Unchanged
    });
  });

  group('EventType constants', () {
    test('predefined event types exist', () {
      expect(EventType.linkClicked, 'link_clicked');
      expect(EventType.linkCreated, 'link_created');
      expect(EventType.appInstalled, 'app_installed');
      expect(EventType.appOpened, 'app_opened');
      expect(EventType.deepLinkOpened, 'deep_link_opened');
      expect(EventType.deferredLinkOpened, 'deferred_link_opened');
    });
  });
}

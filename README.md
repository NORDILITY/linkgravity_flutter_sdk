# SmartLink Flutter SDK

[![Pub Version](https://img.shields.io/pub/v/smartlink_flutter_sdk)](https://pub.dev/packages/smartlink_flutter_sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A comprehensive Flutter SDK for **deferred deep linking**, **link generation**, and **app-to-app attribution**. Fully compatible with **FlutterFlow**.

## Features

- Link Generation - Create SmartLinks programmatically
- Deep Link Handling - Universal Links (iOS) & App Links (Android) 
- Deferred Deep Linking - Attribution matching after app install
- Click Tracking & Analytics - Comprehensive event tracking
- App-to-App Attribution - Track user acquisition sources
- Offline Queue - Track events offline, sync when online
- Custom Event Tracking - Track any custom events
- FlutterFlow Compatible - Ready-to-use Custom Actions
- Privacy-Focused - Device fingerprinting without IDFA/GAID

## Installation

Add to your pubspec.yaml:

```yaml
dependencies:
  smartlink_flutter_sdk: ^1.0.0
```

Then run: `flutter pub get`

## Quick Start

### Initialize the SDK

```dart
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SmartLinkClient.initialize(
    baseUrl: 'https://localhost:3000',
    apiKey: 'your-api-key',
  );

  runApp(MyApp());
}
```

### Create a Link

```dart
final link = await SmartLinkClient.instance.createLink(
  LinkParams(
    longUrl: 'https://example.com/product/123',
    title: 'Amazing Product',
    deepLinkConfig: DeepLinkConfig(
      deepLinkPath: '/product/123',
    ),
  ),
);

print('Short URL: ${link.shortUrl}');
```

### Handle Deep Links

```dart
SmartLinkClient.instance.onDeepLink.listen((deepLink) {
  print('Deep link opened: ${deepLink.path}');
  // Navigate based on deep link
});
```

### Track Events

```dart
await SmartLinkClient.instance.trackEvent('product_viewed', {
  'productId': '123',
});
```

## FlutterFlow Integration

See documentation for FlutterFlow Custom Actions.

## License

MIT License

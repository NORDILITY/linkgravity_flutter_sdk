# LinkGravity Flutter SDK

[![Pub Version](https://img.shields.io/pub/v/linkgravity_flutter_sdk)](https://pub.dev/packages/linkgravity_flutter_sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter SDK for deferred deep linking, link management, and attribution. Works with any navigation system including [FlutterFlow](https://www.flutterflow.io/).

## Installation

```yaml
dependencies:
  linkgravity_flutter_sdk: ^0.2.0
```

```bash
flutter pub get
```

## Quick Start

### Prerequisite

Your app needs to be created in Android Console and or the apple app store (they do not have to be released yet), to get keys for the respective OS to verify the links.
iOS see [setup universal links](https://linkgravity.dartvigation/set-up-universal-links)
Android see [setup app links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links).

For Android you do not need to have the App in Console, you can test with this workaroung: Goto app settings of your App -> open by default -> add link -> choose the link gravity link schema.

### 1. Initialize 

```dart
import 'package:linkgravity_flutter_sdk/linkgravity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LinkGravityClient.initialize(
    baseUrl: 'https://api.linkgravity.io',
    iosApiKey: 'your-ios-api-key',
    androidApiKey: 'your-android-api-key',
  );

  runApp(const MyApp());
}
```

get the `baseUrl` and platform-specific API keys from your [LinkGravity](https://dev.linkgravity.io/) project. You can also use a single universal `apiKey` instead of platform-specific keys (if you target only one mobile OS).

### 2. Handle Deep Links

The SDK resolves short codes automatically and delivers the final route through a callback.

```dart
// In your home page's initState or equivalent
LinkGravityClient.instance.handleDeepLinks(
  onNavigate: (path) {
    // path is the resolved route, e.g. "/product/123?ref=campaign"
    if (context.mounted) context.go(path);
  },
);
```

### 3. Deferred Deep Linking

Deferred deep linking works **automatically on first app launch** — no extra code required. The SDK:

- **Android**: Uses the Play Install Referrer API for 100% deterministic matching, with fingerprint fallback
- **iOS**: Uses fingerprint matching (~85-90% accuracy)

The matched deep link flows through the same `handleDeepLinks` callback you set up above.
<!-- Tested until here -->

## Create & Manage Links

```dart
// Create a link
final link = await LinkGravityClient.instance.createLink(
  LinkParams(
    longUrl: 'https://example.com/product/123',
    title: 'Amazing Product',
    deepLinkConfig: DeepLinkConfig(
      deepLinkPath: '/product/123',
    ),
  ),
);
print('Short URL: ${link.shortUrl}');

// Other operations
final fetched = await LinkGravityClient.instance.getLink(link.id);
final updated = await LinkGravityClient.instance.updateLink(link.id, LinkParams(longUrl: 'https://example.com/new'));
await LinkGravityClient.instance.deleteLink(link.id);
```

## Track Events

```dart
// Custom events
await LinkGravityClient.instance.trackEvent('product_viewed', {
  'productId': '123',
  'category': 'electronics',
});

// Conversions
await LinkGravityClient.instance.trackConversion(
  type: 'purchase',
  revenue: 29.99,
  currency: 'USD',
);
```

Events are batched and sent automatically. If the device is offline, events are queued and sent when connectivity returns.

## Platform Setup

Deep links require platform-specific configuration:


**Android configuration**

1. Navigate to android/app/src/main/AndroidManifest.xml file.

2. Add the following metadata tag and intent filter inside the <activity> tag with .MainActivity.

Replace `{replace_with_your_sub_domain_in_linkgravity}` with your linkgravity subdomain.

Package name can be found in build.gradle.ktr for kotlin or build.grade for java under applicationId.

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="http" android:host="{replace_with_your_sub_domain_in_linkgravity}.links.linkgravity.io" />
    <data android:scheme="https" />
</intent-filter>
```
To test deep links in Android emulator without having sha256 fingerprint of you apk, configure your app in the emulator to accept external links.

**iOS configuration**

1. Open the ios/Runner/Runner.entitlements XML file in your preferred editor.

2. Add an associated domain inside the <dict> tag.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:{replace_with_your_sub_domain_in_linkgravity}.links.linkgravity.io</string>
  </array>
</dict>
</plist>
```

## Configuration

```dart
await LinkGravityClient.initialize(
  baseUrl: 'https://api.linkgravity.io',
  iosApiKey: 'your-ios-api-key',
  androidApiKey: 'your-android-api-key',
  config: LinkGravityConfig(
    enableDeepLinking: true,          // Deep link handling (default: true)
    enableAnalytics: true,            // Event tracking (default: true)
    enableOfflineQueue: true,         // Queue events when offline (default: true)
    enableAutoResolution: false,      // Auto-resolve short codes before route matching (default: false)
    logLevel: LogLevel.info,          // debug | info | warning | error
    batchSize: 20,                    // Events per batch (1-100)
    batchTimeout: Duration(seconds: 30),
    requestTimeout: Duration(seconds: 30),
  ),
);
```

## API Reference

### Link Management

| Method | Description |
|--------|-------------|
| `createLink(LinkParams)` | Create a short link |
| `getLink(String)` | Get link by ID |
| `getLinks({limit, offset, search})` | List links |
| `updateLink(String, LinkParams)` | Update a link |
| `deleteLink(String)` | Delete a link |

### Deep Linking

| Method | Description |
|--------|-------------|
| `handleDeepLinks({onNavigate})` | Unified callback for regular and deferred deep links |
| `onDeepLink` | Stream of raw links delivered by the OS |
| `initialDeepLink` | Raw link string that launched the app (cold start) |
| `resolveShortCode(String)` | Resolve a short code to its target route |

### Analytics & Attribution

| Method | Description |
|--------|-------------|
| `trackEvent(String, Map?)` | Track a custom event |
| `trackConversion({type, revenue, currency})` | Track a conversion |
| `flushEvents()` | Flush pending event batch |
| `getAttribution()` | Get attribution data for this device |
| `setUserId(String)` | Associate events with a user |
| `clearUserId()` | Clear user association |
| `setUTM(UTMParams?)` | Override UTM attribution |
| `getInstallReferrerUTM()` | Get UTM from Android Install Referrer |

## Troubleshooting

**Deep links not opening the app?**
Verify your App Links (Android) or Universal Links (iOS) configuration. Test with `adb shell am start -a android.intent.action.VIEW -d "https://your-domain.com/test"` on Android.

**Deferred deep link not found after install?**
On Android, the app must be installed from the Play Store (not sideloaded) for the Install Referrer to work. On iOS, fingerprint matching can be affected by VPNs or shared networks.

**Events not appearing?**
Check that `enableAnalytics: true` (default) is set. Events are batched — call `flushEvents()` to send immediately, or wait for the batch timeout.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Run tests before submitting:

```bash
flutter test
flutter analyze
```

## License

MIT License — see [LICENSE](LICENSE) for details.

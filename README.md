# LinkGravity Flutter SDK

[![Pub Version](https://img.shields.io/pub/v/linkgravity_flutter_sdk)](https://pub.dev/packages/linkgravity_flutter_sdk)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Flutter SDK for deferred deep linking, link management, and attribution. Works with any navigation system including [FlutterFlow](https://www.flutterflow.io/).

## Installation

```yaml
dependencies:
  linkgravity_flutter_sdk: ^1.2.2
```

```bash
flutter pub get
```

## Quick Start

### 1. Initialize

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LinkGravityClient.initialize(
    baseUrl: 'https://api.linkgravity.io',
    apiKey: 'your-api-key',
  );

  runApp(const MyApp());
}
```

get the `baseUrl` and `apiKey` from your [LinkGravity](https://dev.linkgravity.io/) project.

### 2. Handle Deep Links

The SDK resolves short codes automatically. Pick the approach that fits your app:

**Option A: Simple callback** (recommended for most apps)

```dart
// In your home page's initState or equivalent
LinkGravityClient.instance.handleDeepLinks(
  onNavigate: (path) {
    // path is the resolved route, e.g. "/product/123?ref=campaign"
    if (context.mounted) context.go(path);
  },
);
```

**Option B: Route map** (when you need per-route logic)

```dart
LinkGravityClient.instance.registerRoutes(
  context: context,
  routes: {
    '/product': (deepLink) => RouteAction((ctx, data) {
      final id = data.getParam('id');
      Navigator.of(ctx).pushNamed('/product', arguments: {'id': id});
    }),
    '/profile': (deepLink) => RouteAction((ctx, data) {
      Navigator.of(ctx).pushNamed('/profile');
    }),
  },
);
```

Both options handle cold starts (app launched from a link) and warm starts (link opened while app is running) automatically.

### 3. Deferred Deep Linking

Deferred deep linking works **automatically on first app launch** — no extra code required. The SDK:

- **Android**: Uses the Play Install Referrer API for 100% deterministic matching, with fingerprint fallback
- **iOS**: Uses fingerprint matching (~85-90% accuracy)

The matched deep link flows through the same `handleDeepLinks` or `registerRoutes` callback you set up above.

If you need manual control:

```dart
final deepLinkUrl = await LinkGravityClient.instance.handleDeferredDeepLink(
  onFound: () => print('Deferred deep link found!'),
  onNotFound: () => print('No deferred deep link'),
);
```

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

- **Android** (App Links): [Android setup guide](https://docs.linkgravity.io/sdk/android-setup)
- **iOS** (Universal Links): [iOS setup guide](https://docs.linkgravity.io/sdk/ios-setup)

## Configuration

```dart
await LinkGravityClient.initialize(
  baseUrl: 'https://api.linkgravity.io',
  apiKey: 'your-api-key',
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
| `handleDeepLinks({onNavigate})` | Handle deep links with a simple callback |
| `registerRoutes({context, routes})` | Register route patterns for navigation |
| `onDeepLink` | Stream of incoming deep links |
| `initialDeepLink` | Deep link that launched the app (cold start) |
| `handleDeferredDeepLink({onFound, onNotFound})` | Manually trigger deferred deep link matching |
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

## FlutterFlow

The SDK is fully compatible with FlutterFlow. See the [FlutterFlow integration guide](lib/flutterflow/README.md) for ready-to-use Custom Actions.

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

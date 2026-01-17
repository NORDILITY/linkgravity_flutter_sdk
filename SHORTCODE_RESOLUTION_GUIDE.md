# ShortCode Resolution Guide

## Overview

This guide explains how to use the LinkGravity Flutter SDK's shortCode resolution feature to handle App Links when your app is already installed.

## The Problem

When you configure App Links (Android) or Universal Links (iOS) for a domain, the operating system intercepts **ALL** links from that domain and opens your app directly, bypassing your redirect server.

**Example:**
```
User clicks: https://linkgravity.io/tappick-test
                           ↓
         Android/iOS intercepts the link
                           ↓
              App opens immediately
                           ↓
           App receives: /tappick-test
                           ↓
         ❓ What route should the app navigate to?
```

The app receives `/tappick-test` but doesn't know that it should navigate to `/hidden?ref=Test13`.

## The Solution (Branch.io Pattern)

The LinkGravity SDK follows the industry-standard approach used by Branch.io, Adjust, and AppsFlyer:

1. **Android/iOS intercepts the link** → App opens with shortCode path
2. **SDK calls backend API** → `GET /api/v1/sdk/resolve/tappick-test`
3. **Backend returns the target route** → `{route: "/hidden?ref=Test13"}`
4. **SDK navigates to the resolved route** → App shows the correct screen

This works for **any domain**:
- `https://linkgravity.io/tappick-test` → Same shortCode resolution
- `https://custom.domain.com/tappick-test` → Same shortCode resolution
- `http://192.168.178.75:8080/tappick-test` → Same shortCode resolution

## Implementation

### Method 1: Manual Resolution (Full Control)

Use this approach when you want complete control over the navigation logic.

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

    // Listen for deep links
    LinkGravityClient.instance.onDeepLink.listen((deepLink) async {
      print('Deep link received: ${deepLink.path}');

      // Extract shortCode from path (e.g., /tappick-test → tappick-test)
      final shortCode = deepLink.path.startsWith('/')
          ? deepLink.path.substring(1)
          : deepLink.path;

      // Resolve shortCode to target route
      final result = await LinkGravityClient.instance.resolveShortCode(shortCode);

      if (result != null && result['success'] == true) {
        final route = result['route'] as String; // e.g., '/hidden?ref=Test13'
        final utm = result['utm'] as Map<String, dynamic>?;
        final destination = result['destination'] as String?;

        print('✅ ShortCode resolved: $shortCode → $route');
        print('   Original URL: $destination');
        print('   UTM params: $utm');

        // Navigate to the resolved route
        if (mounted) {
          context.go(route); // Using go_router
          // OR
          // Navigator.of(context).pushNamed(route); // Using standard Navigator
        }
      } else {
        print('❌ Failed to resolve shortCode: $shortCode');
        // Handle fallback - maybe show error page or home screen
        if (mounted) {
          context.go('/');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(child: Text('Home')),
    );
  }
}
```

### Method 2: Automatic Resolution & Navigation (Recommended)

Use this simpler approach when you want the SDK to handle everything automatically.

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();

    // Listen for deep links and auto-resolve + navigate
    LinkGravityClient.instance.onDeepLink.listen((deepLink) async {
      print('Deep link received: ${deepLink.path}');

      final resolved = await LinkGravityClient.instance.resolveAndNavigate(
        deepLink: deepLink,
        context: context,
      );

      if (!resolved) {
        // Handle fallback - shortCode not found or navigation failed
        print('Could not resolve shortCode: ${deepLink.path}');
        if (mounted) {
          context.go('/');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(child: Text('Home')),
    );
  }
}
```

### Method 3: With Registered Routes (Most Flexible)

Combine shortCode resolution with the SDK's route registration feature for the most powerful approach.

```dart
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _setupDeepLinkHandling();
  }

  Future<void> _setupDeepLinkHandling() async {
    // Register route handlers
    LinkGravityClient.instance.registerRoutes(
      context: context,
      routes: {
        '/hidden': (deepLink) => RouteAction((ctx, data) {
          // Custom logic for /hidden route
          final ref = data.getParam('ref');
          print('Navigating to hidden page with ref: $ref');

          ctx.goNamed('HiddenPage', extra: {'ref': ref});
        }),
        '/product': 'ProductPage', // Simple route name
        '/profile': 'ProfilePage',
      },
    );

    // Listen for deep links and resolve shortCodes
    LinkGravityClient.instance.onDeepLink.listen((deepLink) async {
      print('Deep link received: ${deepLink.path}');

      // Try to resolve as shortCode first
      final result = await LinkGravityClient.instance.resolveShortCode(
        deepLink.path.substring(1), // Remove leading slash
      );

      if (result != null && result['success'] == true) {
        final route = result['route'] as String;
        print('✅ ShortCode resolved to: $route');

        // Parse resolved route and trigger registered route handlers
        final routeUri = Uri.parse(route.startsWith('/') ? route : '/$route');
        final resolvedDeepLink = DeepLinkData.fromUri(routeUri);

        // The registered routes will handle navigation automatically
        LinkGravityClient.instance.onDeepLink.add(resolvedDeepLink);
      } else {
        // Not a shortCode, or resolution failed
        // Registered routes will try to handle the original path
        print('Could not resolve shortCode, using original path');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(child: Text('Home')),
    );
  }
}
```

## API Reference

### `resolveShortCode(String shortCode, {String? platform})`

Resolves a shortCode to its target route by calling the backend API.

**Parameters:**
- `shortCode` (required): The short code to resolve (e.g., 'tappick-test')
- `platform` (optional): Platform name ('android' or 'ios'). Auto-detected if not provided.

**Returns:**
```dart
Map<String, dynamic>? {
  'success': true,
  'shortCode': 'tappick-test',
  'route': '/hidden?ref=Test13',       // The target route to navigate to
  'destination': 'https://example.com', // Original long URL
  'utm': {                              // UTM parameters
    'campaign': 'summer-2024',
    'source': 'email',
    'medium': 'newsletter',
    'content': null,
    'term': null
  }
}
```

Returns `null` if the shortCode cannot be resolved (not found, inactive, or API error).

**Example:**
```dart
final result = await LinkGravityClient.instance.resolveShortCode('tappick-test');
if (result != null && result['success'] == true) {
  final route = result['route']; // '/hidden?ref=Test13'
  context.go(route);
}
```

### `resolveAndNavigate({required DeepLinkData deepLink, required BuildContext context, String? platform})`

Convenience method that combines shortCode resolution with automatic navigation.

**Parameters:**
- `deepLink` (required): The deep link data received from the OS
- `context` (required): BuildContext for navigation
- `platform` (optional): Platform name, auto-detected if not provided

**Returns:**
- `true` if the shortCode was resolved and navigation was attempted
- `false` if resolution failed or no shortCode was found

**Example:**
```dart
LinkGravityClient.instance.onDeepLink.listen((deepLink) async {
  final resolved = await LinkGravityClient.instance.resolveAndNavigate(
    deepLink: deepLink,
    context: context,
  );

  if (!resolved) {
    // Fallback to home screen
    context.go('/');
  }
});
```

## Configuration

### Backend Setup

The shortCode resolution endpoint is automatically available at:
```
GET /api/v1/sdk/resolve/:shortCode?platform=android
```

No additional backend configuration is required - the endpoint is public and doesn't require authentication.

### Mobile App Setup

#### Android

Configure your domain in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <!-- Add each domain you want to support -->
    <data android:scheme="https" android:host="linkgravity.io" />
    <data android:scheme="https" android:host="custom.domain.com" />
    <data android:scheme="http" android:host="192.168.178.75" android:port="8080" />
</intent-filter>
```

#### iOS

Configure your domain in `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:linkgravity.io</string>
    <string>applinks:custom.domain.com</string>
</array>
```

And host the `apple-app-site-association` file at:
```
https://linkgravity.io/.well-known/apple-app-site-association
```

## Testing

### Testing Locally (Android)

1. **Create a shortCode link:**
   ```bash
   # In the backend, create a link with shortCode 'tappick-test'
   # Set androidUrl to '/hidden?ref=Test13'
   ```

2. **Send the link via email or SMS:**
   ```
   http://192.168.178.75:8080/tappick-test
   ```

3. **Click the link on your Android device:**
   - Android will intercept the link and open your app
   - Your app will receive `/tappick-test`
   - SDK will call `GET /api/v1/sdk/resolve/tappick-test?platform=android`
   - Backend will return `{route: "/hidden?ref=Test13"}`
   - App will navigate to the `/hidden` screen with `ref=Test13`

### Testing the API Endpoint

```bash
# Test the resolve endpoint directly
curl "http://localhost:3000/api/v1/sdk/resolve/tappick-test?platform=android"

# Expected response:
{
  "success": true,
  "shortCode": "tappick-test",
  "route": "/hidden?ref=Test13",
  "destination": "https://www.example.com",
  "utm": {
    "campaign": "summer-2024",
    "source": "email",
    "medium": null,
    "content": null,
    "term": null
  }
}
```

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ User clicks: https://linkgravity.io/tappick-test               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Android/iOS intercepts link (App Links / Universal Links)      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ App opens and receives: /tappick-test                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ SDK.onDeepLink fires with DeepLinkData(path: '/tappick-test')  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ App calls: resolveShortCode('tappick-test')                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ SDK → Backend: GET /api/v1/sdk/resolve/tappick-test            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Backend queries database for shortCode 'tappick-test'          │
│ Returns: {route: '/hidden?ref=Test13', utm: {...}}             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ App navigates to: /hidden?ref=Test13                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ ✅ User sees the correct screen with correct parameters         │
└─────────────────────────────────────────────────────────────────┘
```

## Comparison to Industry Standards

This implementation follows the same pattern used by major deep linking services:

### Branch.io
```javascript
// Branch SDK automatically resolves deep links
Branch.initSession().then(data => {
  if (data.~referring_link) {
    // Navigate based on Branch data
    navigateTo(data.custom_route);
  }
});
```

### Adjust
```dart
// Adjust SDK provides deferred deep link callback
AdjustConfig config = AdjustConfig(appToken, environment);
config.deferredDeeplinkCallback = (String uri) {
  // Resolve and navigate
  navigateTo(uri);
};
```

### LinkGravity (This Implementation)
```dart
// LinkGravity SDK resolves shortCodes to routes
LinkGravityClient.instance.onDeepLink.listen((deepLink) async {
  final result = await LinkGravityClient.instance.resolveShortCode(
    deepLink.path.substring(1),
  );
  if (result != null) {
    context.go(result['route']);
  }
});
```

All three follow the same core principle:
1. OS intercepts the link
2. SDK calls backend to resolve
3. Backend returns navigation data
4. App navigates to the correct screen

## Troubleshooting

### ShortCode not resolving

**Symptom:** `resolveShortCode()` returns `null`

**Possible causes:**
1. ShortCode doesn't exist in database
2. Link is inactive (`active: false`)
3. Backend API is not reachable
4. Wrong base URL configured in SDK

**Solution:**
```bash
# Verify shortCode exists
curl "http://localhost:3000/api/v1/sdk/resolve/YOUR-SHORTCODE?platform=android"

# Check SDK configuration
print('SDK baseUrl: ${LinkGravityClient.instance.baseUrl}');
```

### Navigation not working

**Symptom:** ShortCode resolves but app doesn't navigate

**Possible causes:**
1. BuildContext is not mounted
2. Route doesn't exist in your router
3. Using wrong navigation method (go vs pushNamed)

**Solution:**
```dart
// Check context before navigation
if (mounted) {
  context.go(route);
}

// Or handle navigation errors
try {
  context.go(route);
} catch (e) {
  print('Navigation failed: $e');
  // Fallback
  Navigator.of(context).pushNamed('/');
}
```

### App Links not intercepting

**Symptom:** Links open in browser instead of app

**Possible causes:**
1. Domain not configured in AndroidManifest/entitlements
2. Digital Asset Links (Android) not verified
3. Apple App Site Association (iOS) file missing

**Solution:**

For Android:
```bash
# Verify Digital Asset Links
curl "https://YOUR-DOMAIN/.well-known/assetlinks.json"

# Should return your app's package name and SHA256 fingerprint
```

For iOS:
```bash
# Verify Apple App Site Association
curl "https://YOUR-DOMAIN/.well-known/apple-app-site-association"

# Should return your app's bundle ID
```

## Best Practices

1. **Always handle resolution failures:**
   ```dart
   final result = await resolveShortCode(shortCode);
   if (result == null) {
     // Fallback to home screen or show error
     context.go('/');
   }
   ```

2. **Use analytics to track resolution:**
   ```dart
   final result = await resolveShortCode(shortCode);
   if (result != null) {
     await LinkGravityClient.instance.trackEvent('shortcode_resolved', {
       'shortCode': shortCode,
       'route': result['route'],
     });
   }
   ```

3. **Cache resolution results (optional):**
   ```dart
   final cache = <String, String>{};

   Future<String?> resolveWithCache(String shortCode) async {
     if (cache.containsKey(shortCode)) {
       return cache[shortCode];
     }

     final result = await resolveShortCode(shortCode);
     if (result != null) {
       cache[shortCode] = result['route'];
       return result['route'];
     }
     return null;
   }
   ```

4. **Handle UTM parameters:**
   ```dart
   final result = await resolveShortCode(shortCode);
   if (result != null) {
     final utm = result['utm'] as Map<String, dynamic>?;
     if (utm != null) {
       // Set attribution
       LinkGravityClient.instance.setUTM(UTMParams.fromJson(utm));

       // Track campaign
       await LinkGravityClient.instance.trackEvent('campaign_opened', utm);
     }
   }
   ```

## Summary

The shortCode resolution feature enables LinkGravity to work like Branch.io for App Links:

- ✅ Works with **any domain** (linkgravity.io, custom.domain.com, local IP)
- ✅ **Platform-aware** routing (different routes for iOS/Android)
- ✅ **UTM attribution** included in response
- ✅ **No authentication required** (public API endpoint)
- ✅ **Industry-standard** approach (same as Branch.io, Adjust, AppsFlyer)

This solves the core problem: **When Android/iOS intercepts App Links, the SDK can still navigate to the correct screen by asking the backend what route the shortCode maps to.**
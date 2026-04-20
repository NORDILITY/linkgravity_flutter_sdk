# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LinkGravity Flutter SDK** - A Flutter plugin for deferred deep linking, link generation, and app-to-app attribution. The SDK is designed to be fully compatible with FlutterFlow while maintaining standard Flutter best practices.

**Key Capabilities:**
- **Deferred Deep Linking**: Android (100% deterministic via Play Install Referrer API), iOS (85-90% probabilistic via fingerprint matching)
- **Link Management**: Create, update, delete, and retrieve LinkGravity short links
- **Deep Link Handling**: Universal Links (iOS) and App Links (Android)
- **Analytics & Attribution**: Event tracking, conversion tracking, and offline queue
- **FlutterFlow Integration**: Custom Actions and simplified route registration API

## Development Commands

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/deferred_deep_link_service_test.dart

# Run tests with coverage
flutter test --coverage
```

### Linting and Analysis
```bash
# Run static analysis
flutter analyze

# Check for linting issues
dart analyze
```

### Building
```bash
# Get dependencies
flutter pub get

# Run code generation (for mockito, if needed)
flutter pub run build_runner build
```

### Example App
```bash
cd example
flutter pub get
flutter run
```

## Architecture

### Core Components

**LinkGravityClient** ([lib/src/linkgravity_client.dart](lib/src/linkgravity_client.dart))
- Singleton main client that orchestrates all SDK functionality
- Manages initialization, service lifecycle, and route registration
- Provides public API for link management, event tracking, and deep linking

**Service Layer** ([lib/src/services/](lib/src/services/))
- `api_service.dart` - HTTP client wrapper with authentication (uses `Authorization: Bearer` header)
- `deferred_deep_link_service.dart` - Orchestrates deferred deep link matching (referrer-first on Android, fingerprint fallback)
- `install_referrer_service.dart` - Android Play Install Referrer integration via platform channel
- `deep_link_service.dart` - Handles incoming Universal/App Links via `app_links` package
- `fingerprint_service.dart` - Device fingerprinting for probabilistic matching (iOS and Android fallback)
- `analytics_service.dart` - Event batching, offline queue, and retry logic
- `storage_service.dart` - Persistent storage via `shared_preferences`

**Model Layer** ([lib/src/models/](lib/src/models/))
- Data classes for API requests/responses
- `route_action.dart` - Callback-based navigation wrapper (no dependency on go_router)
- `deferred_link_response.dart` - Wraps deferred link results with match method metadata

### Platform Integration

**Android Native** ([android/src/main/kotlin/](android/src/main/kotlin/))
- `LinkGravityFlutterSdkPlugin.kt` - Flutter plugin registration
- `InstallReferrerHandler.kt` - Play Install Referrer API integration (100% deterministic matching)
- Requires `com.android.installreferrer:installreferrer:2.2` dependency

**iOS Native** ([ios/Classes/](ios/Classes/))
- Plugin registration only - no custom native code required
- Fingerprint matching handled in Dart layer

### Deferred Deep Linking Strategy

The SDK automatically selects the best matching method:

1. **Android**: Try Play Install Referrer first (deterministic), fall back to fingerprint if unavailable
2. **iOS**: Always use fingerprint matching (probabilistic)

The `DeferredDeepLinkService` includes retry logic with exponential backoff (3 attempts max: 2s, 4s intervals) and does NOT retry on 404/400 errors.

## FlutterFlow Specifics

**FlutterFlow Integration Files** ([lib/flutterflow/](lib/flutterflow/))
- `actions.dart` - Pre-built Custom Actions (has FlutterFlow-specific imports, will show errors in normal IDE)
- `README.md` - Integration guide for FlutterFlow developers

**Important**: Files in [lib/flutterflow/](lib/flutterflow/) are **examples only** and meant to be copied into FlutterFlow projects. They reference FlutterFlow-specific imports that don't exist in this package.

**Key Documentation**:
- [FLUTTERFLOW_LOCAL_USAGE.md](FLUTTERFLOW_LOCAL_USAGE.md) - How to use SDK locally in FlutterFlow via Git dependency
- [FLUTTERFLOW_LOCAL_TESTING.md](FLUTTERFLOW_LOCAL_TESTING.md) - Testing guide for FlutterFlow integration

## Important Implementation Details

### Authentication
The SDK uses `Authorization: Bearer <apiKey>` header format (not `X-API-Key`). This was a critical fix documented in [JIRA-SDK-002-SDK.md](JIRA-SDK-002-SDK.md).

### API Response Parsing
Backend wraps deferred link responses in `{ success: bool, match: {...} }`. The SDK handles both wrapped and flat responses for backward compatibility.

### RouteAction Migration
v1.0.1 introduced a breaking change moving from named constructors (`RouteAction.goNamed()`) to callback-only pattern (`RouteAction((ctx, data) => ...)`). See [MIGRATION_ROUTE_ACTION.md](MIGRATION_ROUTE_ACTION.md) for migration guide.

### Dart Version Compatibility
- Dart SDK: `>=3.0.0 <4.0.0`
- Compatible with Dart 3.8.1 (used by FlutterFlow)
- Flutter: `>=3.10.0`

### Package Structure
This is a Flutter plugin package with:
- Platform channels for Android (Play Install Referrer)
- iOS plugin registration (no custom native code)
- Public API exposed through [lib/linkgravity_flutter_sdk.dart](lib/linkgravity_flutter_sdk.dart)

## Key Documentation Files

- [README.md](README.md) - Main SDK documentation and API reference
- [DEFERRED_DEEP_LINKING_IMPLEMENTATION.md](DEFERRED_DEEP_LINKING_IMPLEMENTATION.md) - Technical deep dive on deferred deep linking
- [PRIVACY_DEFERRED_DEEP_LINKING_GUIDE.md](PRIVACY_DEFERRED_DEEP_LINKING_GUIDE.md) - Privacy considerations and fingerprinting details
- [CHANGELOG.md](CHANGELOG.md) - Version history and breaking changes

## Common Patterns

### Adding a New Service Method
1. Add method to appropriate service in [lib/src/services/](lib/src/services/)
2. Expose through LinkGravityClient in [lib/src/linkgravity_client.dart](lib/src/linkgravity_client.dart)
3. Export in [lib/linkgravity_flutter_sdk.dart](lib/linkgravity_flutter_sdk.dart) if public API
4. Add unit tests in [test/services/](test/services/)

### Adding a New Model
1. Create model file in [lib/src/models/](lib/src/models/)
2. Include `fromJson()`, `toJson()`, and `copyWith()` methods
3. Export in [lib/linkgravity_flutter_sdk.dart](lib/linkgravity_flutter_sdk.dart)
4. Add unit tests in [test/models/](test/models/)

### Working with Platform Channels
- Android: Modify [android/src/main/kotlin/](android/src/main/kotlin/) Kotlin files
- Dart interface: [lib/linkgravity_flutter_sdk_platform_interface.dart](lib/linkgravity_flutter_sdk_platform_interface.dart)
- Method channel: [lib/linkgravity_flutter_sdk_method_channel.dart](lib/linkgravity_flutter_sdk_method_channel.dart)

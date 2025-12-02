# Changelog

All notable changes to the LinkGravity Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2025-12-02

### Fixed
- **[IOS-001] Type Conversion in ATTService**: Fixed type conversion errors in iOS ATT (App Tracking Transparency) service
  - Added explicit `Int()` conversion for `ATTrackingManager.AuthorizationStatus.rawValue` (which is `UInt`)
  - Affects `getTrackingAuthorizationStatus()` method (line 23)
  - Affects `requestTrackingAuthorization()` completion handler (line 63)
  - Resolves build errors on iOS when using the ATT framework
- **[IOS-002] SKAdNetwork Switch Statement**: Fixed exhaustive switch warning in SKAdNetworkService
  - Changed `@unknown default` to `default` in ConversionValue.toString() (line 171)
  - Resolves compilation warning in iOS 16.1+ where `@unknown default` makes switch non-exhaustive
- **[API-002] Event Batch Format**: Fixed event batch format to match backend API schema
  - Backend expects `{ events: [{ type, properties, ... }] }` format
  - SDK was sending `{ events: [{ name, data, ... }] }` format
  - Added transformation in `ApiService.sendBatch()` to convert `name` → `type` and `data` → `properties`
  - Resolves 400 Bad Request errors when sending analytics events

### Improved
- **[DEBUG-001] Enhanced Deep Link Debugging**: Added comprehensive debug logging for iOS deep link troubleshooting
  - Added 🔍 emoji-tagged logs throughout deep link flow
  - Shows deferred link parsing, route matching, and navigation execution
  - Helps diagnose iOS-specific deep linking issues

### Breaking Changes
- None (bug fix only)

## [1.1.0] - 2025-11-21

### Fixed
- **[AUTH-001] Authentication Header Format**: Fixed SDK authentication to use `Authorization: Bearer` header format instead of `X-API-Key` header. This aligns with backend API requirements and industry standards.
- **[PARSE-001] Response Parsing**: Updated response parsing to handle wrapped response format `{ success, match: {...} }` from backend while maintaining backward compatibility with flat responses.
- **[TIMEOUT-001] Request Timeout**: Reduced default request timeout from 30 seconds to 15 seconds for better user experience and faster error detection.

### Improved
- **[RETRY-001] Network Resilience**: Added automatic retry logic with exponential backoff for deferred deep link lookups:
  - Up to 3 attempts with exponential backoff (2s, 4s, 8s delays)
  - Does NOT retry on client errors (400, 404)
  - Retries on network timeouts and server errors (500+)
  - 10-second timeout per attempt
- **Response Handling**: Enhanced `DeferredLinkResponse` and `DeepLinkMatch` models to correctly parse both wrapped and flat response formats.
- **API Service**: Exposed `headers` property for testing purposes (was previously private).

### Tests
- Added comprehensive unit tests for authentication header format
- Added tests for response parsing (both wrapped and flat formats)
- Added tests for retry logic behavior and exponential backoff calculations
- All existing tests continue to pass (34 tests total)

### Breaking Changes
- None (all changes are backward compatible)

### Dependencies
- No new dependencies added
- No dependency version changes

### Migration Guide
No action required. Update to version 1.1.0 for:
- Correct backend authentication
- Better network reliability with automatic retries
- Improved response time with reduced timeout

## [1.0.0] - 2025-11-19

### Added
- Initial release of LinkGravity Flutter SDK
- Link generation API (create, get, update, delete links)
- Deep link handling (Universal Links for iOS, App Links for Android)
- Deferred deep linking with device fingerprinting
- Analytics and event tracking
- Offline event queue with automatic retry
- App-to-app attribution tracking
- Conversion tracking
- FlutterFlow Custom Actions
- Comprehensive documentation and README
- Example app demonstrating all features

### Features
- Privacy-safe device fingerprinting (no IDFA/GAID required)
- Automatic batch processing of analytics events
- Configurable SDK settings
- Session tracking
- User identification
- Custom metadata support
- Error handling and retry logic
- Debug logging

### Platform Support
- iOS 11+
- Android 5.0+ (API 21+)
- Web (experimental)
- Desktop (macOS, Windows, Linux - experimental)

### Dependencies
- Flutter SDK >= 3.38.0
- Dart SDK >= 3.10.0
- http: ^1.6.0
- shared_preferences: ^2.5.3
- app_links: ^7.0.0
- device_info_plus: ^12.2.0
- package_info_plus: ^9.0.0
- uuid: ^4.5.2
- crypto: ^3.0.7
- connectivity_plus: ^7.0.0

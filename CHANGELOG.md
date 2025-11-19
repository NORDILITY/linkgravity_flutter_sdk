# Changelog

All notable changes to the SmartLink Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-19

### Added
- Initial release of SmartLink Flutter SDK
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

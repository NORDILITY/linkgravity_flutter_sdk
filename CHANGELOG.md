# Changelog

All notable changes to the LinkGravity Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-04

### Added
- Initial beta release of LinkGravity Flutter SDK
- Link management API (create, get, list, update, delete links)
- Deep link handling for Universal Links on iOS and App Links on Android
- Short-code resolution and unified deep link processing for cold start and warm start flows
- Deferred deep linking with Android Play Install Referrer matching and fingerprint fallback, plus iOS fingerprint matching
- Analytics event tracking with batching, manual flushing, offline queueing, and automatic retry
- Attribution APIs for app-to-app attribution, UTM handling, cached install attribution, and user association
- Conversion tracking APIs
- iOS attribution support with ATT / IDFA access and SKAdNetwork conversion updates
- FlutterFlow integration helpers and custom actions
- Comprehensive documentation and README
- Example app demonstrating the SDK features

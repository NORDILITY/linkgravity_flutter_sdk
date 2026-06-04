# Changelog

All notable changes to the LinkGravity Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-04

### Added
- Click attribution for links that bypass the redirect server. When the OS opens the app directly via an iOS Universal Link or Android App Link, the SDK now tags the `/resolve` call with a `source` (`ios_universal_link` / `android_app_link`) so the backend can count the click that never reached the redirect server.
- `LinkGravityConfig.linkHosts` — an optional allow-list of LinkGravity short-link hosts. When set, incoming `http(s)` links whose host is not in the list are passed straight to `onNavigate` (the host app's router) instead of being resolved. Defaults to empty, which preserves the previous "resolve every link" behavior.
- `LinkGravityConfig.platformOverride` — test/diagnostic seam to force `ios` / `android` attribution behavior; defaults to the real platform.
- `resolveShortCode` (client and `ApiService`) now accept `source`, `cid`, and `fingerprint` parameters, forwarded to `/api/v1/sdk/resolve` as `source`, `cid`, and `fp`.

### Changed
- `processDeepLink` now selects a single click-attribution path to avoid double counting:
  - Deferred deep link matches send neither `source` nor `cid` (the click was already counted on the original web click before install).
  - Links carrying a redirect-server `lgr_cid` marker send it as `cid` so the backend correlates to the existing click instead of creating a new one; the `lgr_cid` parameter is stripped before navigation so it never leaks into the host app's route.
  - Plain `http(s)` Universal/App Links send `source` so the backend counts the bypassed click.
- A device fingerprint is now generated only on the click-counting path (used by the backend's short dedup window), avoiding an unnecessary device-info lookup on other flows.

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

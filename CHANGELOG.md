# Changelog

All notable changes to the LinkGravity Flutter SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-09-19

### Fixed
- **Analytics events now reach the dashboard.** Batches carry `deviceId` and `linkId`, so the backend can attribute them and scope them to a project. Without that the events were stored and then filtered out by every dashboard query — the Events chart read zero no matter how many events an app sent, and nothing reported an error.
- `trackEvent` no longer blocks the caller. Every `batchSize`-th call awaited an HTTP round trip, which freezes the UI when it happens inside an `onPressed` handler on a bad connection. The flush is fired without awaiting; the queue is cleared before the first suspension, so no batch is sent twice.
- `setUserId` is no longer discarded. The value was attached to every event and then dropped when the batch was serialised, so identity stitching had nothing to work with.

### Added
- `trackConversion(transactionId: ...)`. **Pass it for anything with revenue.** Mobile networks make retries routine, and without a deduplication key one purchase is recorded once per retry. Repeats now collapse onto the first write. Also exposed on the FlutterFlow action.
- `trackConversion` sends `deviceId`, so a conversion is attributed from the device's install when no `linkId` is given.

### Changed
- **Breaking:** event batches post to `POST /api/v1/sdk/events` instead of `POST /api/v1/events`. The old path still accepts API-key batches for one release and will then be session-only. Requires a backend from 19 Sep 2026 or later.

### Removed
- **Breaking:** `trackConversion(eventId: ...)`. The backend dropped the field — no SDK path could fill it: the id it referred to is generated server-side and never returned to the client.
- `ApiService.trackEvent` — unreachable from any public method, and aimed at a path that is becoming session-only. Same cleanup 0.4.0 applied to its siblings.

## [0.4.0] - 2026-09-14

### Removed
- **Breaking:** `getLink`, `getLinks`, `updateLink`, `deleteLink`. They called `/api/v1/links*`, which is authenticated by session JWT, so an API key could never pass — all four returned 401 in every released version. Link management stays in the dashboard: the key an app ships with is a public key, extractable from the binary.
- `ApiService.createLink`, `trackSdkEvent`, `trackClick` — unreachable from any public method. `trackClick` targeted a route that has never existed; `trackSdkEvent` duplicated `POST /api/v1/events`, which is what event tracking already uses.

### Fixed
- `createLink` now reaches the backend. It posted to `/api/sdk/links`; the SDK router is mounted at `/api/v1/sdk`, so every call 404'd. Link creation has never succeeded in a released version.
- `createLink`'s request body now matches the API: `destination` (was `longUrl`), flat `path`/`fallbackUrl` (was a nested `deepLinkConfig`), and UTM values as their own fields (was a `utmParams` map). `LinkParams(longUrl:)` and `DeepLinkConfig` are unchanged — only the JSON differs.
- `createLink` no longer throws while parsing a successful response. `LinkGravity.fromJson` required `longUrl`; the API returns `destination`.
- `LinkParams.validate()` accepted `https://example.com/p` but rejected `https://example.com` — it checked `hasAbsolutePath`, which is about the path, not the URL. It also threw on malformed input instead of returning false.
- `getAttribution()` returned `null` in every version: the only writer to the cache it reads was a network call to a route that does not exist. The deferred-match flow now persists what it receives, so `getAttribution()` returns it. `null` now means an organic install, or that the match has not run yet.
- README: the Android intent-filter and the iOS associated-domains entitlement both named `{…}.links.linkgravity.io`. Links are served from `linkg.io`, and that host serves neither `assetlinks.json` nor the AASA — App Links and Universal Links verification failed silently and every link opened the browser. Also a corrupted Flutter docs URL and a dashboard link pointing at the development environment.

### Added
- `test/services/api_contract_test.dart` — pins every endpoint path and the create request body against the backend. Nothing asserted either before, which is why none of the above was caught.
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

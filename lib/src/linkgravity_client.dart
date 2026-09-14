import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'models/link.dart';
import 'models/link_params.dart';
import 'models/attribution.dart';
import 'models/analytics_event.dart';
import 'models/utm_params.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/fingerprint_service.dart';
import 'services/deep_link_service.dart';
import 'services/deferred_deep_link_service.dart';
import 'services/analytics_service.dart';
import 'services/install_referrer_service.dart';
import 'services/skadnetwork_service.dart';
import 'services/idfa_service.dart';
import 'linkgravity_config.dart';
import 'utils/logger.dart';

/// Main LinkGravity SDK client
///
/// This is the primary class for integrating LinkGravity into your Flutter app.
///
/// Example usage:
/// ```dart
/// // Initialize SDK
/// final linkGravity = await LinkGravityClient.initialize(
///   baseUrl: 'https://api.linkgravity.io',
///   iosApiKey: 'your-ios-api-key',
///   androidApiKey: 'your-android-api-key',
/// );
///
/// // Create a link
/// final link = await linkGravity.createLink(
///   LinkParams(longUrl: 'https://example.com/product/123'),
/// );
///
/// // Listen for deep links
/// linkGravity.onDeepLink.listen((link) {
///   print('Deep link opened: $link');
/// });
/// ```
class LinkGravityClient {
  /// Singleton instance
  static LinkGravityClient? _instance;

  /// Get singleton instance (must call [initialize] first)
  static LinkGravityClient get instance {
    if (_instance == null) {
      throw StateError(
        'LinkGravity not initialized. Call LinkGravityClient.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Base URL of LinkGravity backend
  final String baseUrl;

  /// API Key for authentication
  final String? apiKey;

  /// SDK Configuration
  final LinkGravityConfig config;

  // Services
  late final ApiService _api;
  late final StorageService _storage;
  late final FingerprintService _fingerprint;
  late final DeepLinkService _deepLink;
  late final InstallReferrerService _installReferrer;
  late final AnalyticsService _analytics;
  late final SKAdNetworkService _skadnetwork;
  late final IDFAService _idfa;

  /// Whether SDK has been initialized
  bool _initialized = false;

  /// Device fingerprint
  String? _deviceFingerprint;

  /// Device ID (Android ID or iOS IDFV)
  String? _deviceId;

  /// App version
  String? _appVersion;

  // Deep link handler state
  StreamSubscription<String>? _linkSubscription;
  StreamSubscription<String>? _resolvedLinkSubscription;
  Function(String)? _globalOnNavigate;

  /// Private constructor
  LinkGravityClient._({
    required this.baseUrl,
    this.apiKey,
    required this.config,
  }) {
    // Initialize logger
    LinkGravityLogger.setLevel(config.logLevel);

    // Initialize services
    _storage = StorageService();
    _fingerprint = FingerprintService();
    _api = ApiService(
      baseUrl: baseUrl,
      apiKey: apiKey,
      timeout: config.requestTimeout,
    );
    _deepLink = DeepLinkService();
    _installReferrer = InstallReferrerService(_storage);
    _analytics = AnalyticsService(
      api: _api,
      storage: _storage,
      installReferrer: _installReferrer,
      batchSize: config.batchSize,
      batchTimeout: config.batchTimeout,
      enabled: config.enableAnalytics,
      offlineQueueEnabled: config.enableOfflineQueue,
    );
    _skadnetwork = SKAdNetworkService(apiService: _api);
    _idfa = IDFAService();
  }

  /// Creates an instance for testing with injectable dependencies.
  ///
  /// Bypasses platform-dependent initialization (PackageInfo, SharedPreferences)
  /// and allows direct injection of service instances.
  @visibleForTesting
  LinkGravityClient.forTesting({
    required this.baseUrl,
    this.apiKey,
    required this.config,
    required ApiService api,
    required DeepLinkService deepLink,
    required FingerprintService fingerprint,
    required StorageService storage,
    required AnalyticsService analytics,
  }) {
    LinkGravityLogger.setLevel(config.logLevel);
    _api = api;
    _deepLink = deepLink;
    _fingerprint = fingerprint;
    _storage = storage;
    _installReferrer = InstallReferrerService(storage);
    _analytics = analytics;
    _skadnetwork = SKAdNetworkService(apiService: api);
    _idfa = IDFAService();
    _initialized = true;
  }

  /// Resets the singleton instance. Only for use in tests.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Initialize the LinkGravity SDK
  ///
  /// This must be called before using any other SDK features.
  /// Typically called in your app's main() function or app startup.
  ///
  /// Parameters:
  /// - [baseUrl]: Base URL of your LinkGravity backend (e.g., 'https://api.linkgravity.io')
  /// - [apiKey]: Universal API key used on all platforms (optional)
  /// - [iosApiKey]: iOS-specific API key (takes priority over [apiKey] on iOS)
  /// - [androidApiKey]: Android-specific API key (takes priority over [apiKey] on Android)
  /// - [config]: SDK configuration (optional)
  ///
  /// You can provide platform-specific keys, a universal key, or both.
  /// Platform-specific keys take priority over the universal [apiKey].
  ///
  /// Example with platform-specific keys:
  /// ```dart
  /// await LinkGravityClient.initialize(
  ///   baseUrl: 'https://api.linkgravity.io',
  ///   iosApiKey: 'your-ios-api-key',
  ///   androidApiKey: 'your-android-api-key',
  /// );
  /// ```
  ///
  /// Returns initialized [LinkGravityClient] instance
  static Future<LinkGravityClient> initialize({
    required String baseUrl,
    String? apiKey,
    String? iosApiKey,
    String? androidApiKey,
    LinkGravityConfig? config,
  }) async {
    if (_instance != null) {
      LinkGravityLogger.warning(
        'LinkGravity already initialized, returning existing instance',
      );
      return _instance!;
    }

    LinkGravityLogger.info('Initializing LinkGravity SDK...');

    // Resolve platform-specific API key
    String? resolvedApiKey = apiKey;
    if (Platform.isIOS && iosApiKey != null) {
      resolvedApiKey = iosApiKey;
      LinkGravityLogger.debug('Using iOS-specific API key');
    } else if (Platform.isAndroid && androidApiKey != null) {
      resolvedApiKey = androidApiKey;
      LinkGravityLogger.debug('Using Android-specific API key');
    }

    _instance = LinkGravityClient._(
      baseUrl: baseUrl,
      apiKey: resolvedApiKey,
      config: config ?? LinkGravityConfig(),
    );

    await _instance!._init();

    return _instance!;
  }

  /// Internal initialization
  Future<void> _init() async {
    if (_initialized) return;

    LinkGravityLogger.info('LinkGravity SDK ${config.toString()}');

    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      LinkGravityLogger.debug('App version: $_appVersion');

      // Initialize analytics service
      await _analytics.initialize();

      // Generate/retrieve device fingerprint
      _deviceFingerprint = await _storage.getFingerprint();
      if (_deviceFingerprint == null) {
        _deviceFingerprint = await _fingerprint.generateFingerprint();
        await _storage.saveFingerprint(_deviceFingerprint!);
        LinkGravityLogger.info('New device fingerprint generated');
      } else {
        LinkGravityLogger.debug('Existing fingerprint loaded');
      }

      // Set fingerprint in analytics
      _analytics.setFingerprint(_deviceFingerprint!);

      // Get device ID
      _deviceId = await _storage.getDeviceId();
      if (_deviceId == null) {
        // Use fingerprint as device ID (fallback)
        _deviceId = _deviceFingerprint;
        await _storage.saveDeviceId(_deviceId!);
      }

      // Initialize deep linking if enabled
      if (config.enableDeepLinking) {
        await _deepLink.initialize();

        // Handle deferred deep links (first launch)
        await _handleDeferredDeepLink();

        LinkGravityLogger.info('Deep linking enabled');
      }

      // Track app open event
      if (config.enableAnalytics) {
        await _trackAppOpen();
      }

      _initialized = true;
      LinkGravityLogger.info('LinkGravity SDK initialized successfully');
    } catch (e, stackTrace) {
      LinkGravityLogger.error(
        'Failed to initialize LinkGravity SDK',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Handle deferred deep link on first app launch
  ///
  /// Uses the best available matching method:
  /// - Android: Play Install Referrer (deterministic, 100% accuracy) → Fingerprint (fallback)
  /// - iOS: Fingerprint only (probabilistic, ~85-90% accuracy)
  Future<void> _handleDeferredDeepLink() async {
    LinkGravityLogger.info('🔍 Starting deferred deep link check...');

    final isFirstLaunch = await _storage.isFirstLaunch();

    LinkGravityLogger.info('🔍 isFirstLaunch result: $isFirstLaunch');

    if (!isFirstLaunch && !config.debugSimulateFirstLaunch) {
      LinkGravityLogger.warning(
        '⚠️ Not first launch, skipping deferred deep link check',
      );
      return;
    }

    if (config.debugSimulateFirstLaunch) {
      LinkGravityLogger.warning(
        '🔍 DEBUG: Simulating first launch (forcing deferred check)',
      );
    }

    LinkGravityLogger.info(
      '✅ First launch detected, checking for deferred deep link...',
    );

    try {
      // Create deferred deep link service with Android referrer support
      // Pass device info so backend can create Install record during match
      final deferredService = DeferredDeepLinkService(
        apiService: _api,
        fingerprintService: _fingerprint,
        storageService: _storage,
        deviceId: _deviceId,
        deviceFingerprint: _deviceFingerprint,
        appVersion: _appVersion,
      );

      // Try to match using best available method (referrer on Android, fingerprint on iOS)
      // Uses retry logic with exponential backoff for better reliability
      final match = await deferredService.matchDeferredDeepLinkWithRetry();

      LinkGravityLogger.debug(
        '🔍 Match result: ${match != null ? "not null" : "NULL"}',
      );
      if (match != null) {
        LinkGravityLogger.debug('🔍 match.success: ${match.success}');
        LinkGravityLogger.debug('🔍 match.deepLinkUrl: ${match.deepLinkUrl}');
        LinkGravityLogger.debug('🔍 match.linkId: ${match.linkId}');
        LinkGravityLogger.debug('🔍 match.matchMethod: ${match.matchMethod}');
      }

      if (match != null && match.success && match.deepLinkUrl != null) {
        LinkGravityLogger.info(
          '✅ Deferred deep link: ${match.deepLinkUrl} (method: ${match.matchMethod})',
        );

        await _analytics.trackEvent(EventType.deferredLinkOpened, {
          'linkId': match.linkId,
          'shortCode': match.shortCode,
          'matchMethod': match.matchMethod,
          'deepLinkUrl': match.deepLinkUrl,
          ...?match.params,
        });

        // Persist what the match told us, so getAttribution() has something to return.
        //
        // Nothing wrote this store before, and the only reader fetched from an endpoint
        // that does not exist — so getAttribution() returned null in every version, for
        // every caller, including the FlutterFlow action wrapping it. The data was always
        // right here and simply discarded.
        await _storage.saveAttribution(
          AttributionData(
            id: match.linkId ?? match.shortCode ?? 'deferred',
            linkId: match.linkId,
            shortCode: match.shortCode,
            deepLinkPath: match.deepLinkUrl,
            deepLinkParams: match.params?.map((k, v) => MapEntry(k, v.toString())),
            isDeferred: true,
            firstOpenedAt: DateTime.now(),
          ),
        );

        final link = match.deepLinkUrl!;
        final isResolved = match.isResolved ?? false;

        _deepLink.initialLink = link;
        _deepLink.initialLinkResolved = isResolved;
        // Click was already counted when the user clicked the short URL in
        // the browser before installing — don't tag /resolve with a click
        // source on first launch.
        _deepLink.initialLinkFromDeferred = true;

        if (isResolved) {
          _deepLink.resolvedLinkController.add(link);
        } else {
          _deepLink.linkController.add(link);
        }
      } else {
        LinkGravityLogger.debug('No deferred deep link found');
      }
    } catch (e, stackTrace) {
      LinkGravityLogger.error(
        'Error handling deferred deep link',
        e,
        stackTrace,
      );
    }

    // Mark as launched (even if matching failed)
    await _storage.markAsLaunched();
  }

  /// Track app open event
  Future<void> _trackAppOpen() async {
    await _analytics.trackEvent(EventType.appOpened, {
      'appVersion': _appVersion,
      'platform': await _fingerprint.getPlatformName(),
      'deviceModel': await _fingerprint.getDeviceModel(),
      'osVersion': await _fingerprint.getOSVersion(),
      'isPhysicalDevice': await _fingerprint.isPhysicalDevice(),
      ...?config.globalMetadata,
    });
  }

  // ============================================================================
  // LINK MANAGEMENT
  // ============================================================================

  /// Create a new LinkGravity link
  ///
  /// Example:
  /// ```dart
  /// final link = await linkGravity.createLink(
  ///   LinkParams(
  ///     longUrl: 'https://example.com/product/123',
  ///     title: 'Amazing Product',
  ///     deepLinkConfig: DeepLinkConfig(
  ///       deepLinkPath: '/product/123',
  ///     ),
  ///   ),
  /// );
  /// print('Short URL: ${link.shortUrl}');
  /// ```
  Future<LinkGravity> createLink(LinkParams params) async {
    _ensureInitialized();

    LinkGravityLogger.info('Creating dynamic link: ${params.longUrl}');

    // Use the secure SDK endpoint for creation
    final link = await _api.createDynamicLink(params);

    // Track link created event
    if (config.enableAnalytics) {
      await _analytics.trackEvent(EventType.linkCreated, {
        'linkId': link.id,
        'shortCode': link.shortCode,
        'longUrl': link.longUrl,
      });
    }

    return link;
  }

  // getLink / getLinks / updateLink / deleteLink were removed in 0.4.0.
  //
  // They called /api/v1/links*, which is authenticated by session JWT, so an API key could
  // never pass and all four returned 401 in every released version. They are not coming
  // back in this form: the credential an app holds is a *public* key compiled into its
  // binary and extractable from it, and "list, rewrite and delete every link in this
  // project" is a far larger grant than createLink — which is additive, rate-limited and
  // domain-whitelisted. Managing links belongs to the dashboard, or to a server-side
  // integration holding a secret key.

  // ============================================================================
  // DEEP LINKING
  // ============================================================================

  /// Stream of raw incoming deep link strings from the OS.
  ///
  /// Each event is the link as received (e.g. `https://example.com/abc123`
  /// or `myapp://details`). Most apps should use [handleDeepLinks] instead —
  /// it handles resolution and navigation automatically.
  Stream<String> get onDeepLink => _deepLink.linkStream;

  /// The initial deep link string captured on cold start, if any.
  String? get initialDeepLink => _deepLink.initialLink;

  /// Resolve a shortCode to its target route.
  ///
  /// Pass [source] (`ios_universal_link` | `android_app_link`) when the
  /// link bypassed the redirect server, so the backend can count the click.
  /// Pass [cid] instead when the redirect server already counted it and
  /// threaded the click id through to the app via `?lgr_cid=...`.
  /// Pass [fingerprint] alongside [source] so the backend can dedupe repeat
  /// /resolve calls from the same device.
  ///
  /// Returns the raw API response map with `success`, `route` (plain path),
  /// `destination`, and `utm` fields, or null if the lookup fails.
  Future<Map<String, dynamic>?> resolveShortCode(
    String shortCode, {
    String? platform,
    String? source,
    String? cid,
    String? fingerprint,
  }) async {
    _ensureInitialized();

    // Auto-detect platform if not provided
    platform ??= await _fingerprint.getPlatformName();

    LinkGravityLogger.info(
      'Resolving shortCode: $shortCode (platform: $platform, source: ${source ?? "none"}, cid: ${cid ?? "none"})',
    );

    final result = await _api.resolveShortCode(
      shortCode,
      platform: platform,
      source: source,
      cid: cid,
      fingerprint: fingerprint,
    );

    if (result != null && result['success'] == true) {
      // Track shortCode resolution event
      if (config.enableAnalytics) {
        await _analytics.trackEvent(EventType.deepLinkOpened, {
          'shortCode': shortCode,
          'route': result['route'],
          'destination': result['destination'],
          'platform': platform,
          if (source != null) 'source': source,
          if (cid != null) 'cid': cid,
        });
      }

      return result;
    }

    LinkGravityLogger.warning('Failed to resolve shortCode: $shortCode');
    return null;
  }

  /// Handles deep links end-to-end: subscribes to the OS streams and invokes
  /// [onNavigate] with the final resolved path.
  ///
  /// Covers all three entry points:
  /// - Cold start (OS-delivered initial link)
  /// - Warm start (links received while the app is running)
  /// - Programmatic calls to [processDeepLink]
  ///
  /// Pre-resolved deferred links (from the install-referrer / fingerprint
  /// match) skip the /resolve call and are passed straight to [onNavigate].
  ///
  /// Example:
  /// ```dart
  /// LinkGravityClient.instance.handleDeepLinks(
  ///   onNavigate: (path) {
  ///     if (context.mounted) context.go(path);
  ///   },
  /// );
  /// ```
  void handleDeepLinks({required Function(String) onNavigate}) {
    _ensureInitialized();
    LinkGravityLogger.info('🔗 Deep link handler initialized');

    _globalOnNavigate = onNavigate;

    _linkSubscription?.cancel();
    _linkSubscription = _deepLink.linkStream.listen(
      (link) => processDeepLink(link),
      onError: (e, s) => LinkGravityLogger.error('Stream Error', e, s),
    );

    _resolvedLinkSubscription?.cancel();
    _resolvedLinkSubscription = _deepLink.resolvedLinkStream.listen(
      (link) => processDeepLink(link, isResolved: true),
      onError: (e, s) => LinkGravityLogger.error('Resolved Stream Error', e, s),
    );

    final coldLink = _deepLink.initialLink;
    if (coldLink != null) {
      final coldResolved = _deepLink.initialLinkResolved;
      final coldFromDeferred = _deepLink.initialLinkFromDeferred;
      _deepLink.initialLink = null;
      _deepLink.initialLinkResolved = false;
      _deepLink.initialLinkFromDeferred = false;
      // Small delay so the app's router is mounted before we navigate.
      Future.delayed(
        const Duration(milliseconds: 500),
        () => processDeepLink(
          coldLink,
          isResolved: coldResolved,
          isFromDeferredMatch: coldFromDeferred,
        ),
      );
    }
  }

  /// Process a raw deep link string (path or URI).
  ///
  /// Accepts any of:
  /// - Plain path: `/details`, `/parent/child`
  /// - HTTP(S) URL: `https://example.com/details?promo=summer`
  /// - Custom-scheme URI: `myapp://details`
  ///
  /// Extracts the shortCode (last path segment), resolves it against the
  /// backend, and invokes the `onNavigate` callback registered via
  /// [handleDeepLinks] with the resolved route plus any incoming query params.
  /// Falls back to the original path if resolution fails.
  ///
  /// Set [isResolved] to true to skip the /resolve call and navigate directly
  /// to [link] (used for deferred deep link matches that return a pre-resolved
  /// route).
  ///
  /// Set [isFromDeferredMatch] to true when the link originates from a
  /// deferred deep link match. The click was already counted server-side on
  /// the web before install, so /resolve must not be tagged with a click
  /// source.
  Future<void> processDeepLink(
    String link, {
    bool isResolved = false,
    bool isFromDeferredMatch = false,
  }) async {
    _ensureInitialized();
    if (_globalOnNavigate == null) {
      LinkGravityLogger.warning(
        'processDeepLink called before handleDeepLinks — nothing to navigate',
      );
      return;
    }
    if (link.isEmpty || link == '/') return;

    final (path, params) = _splitLink(link);
    if (path.isEmpty || path == '/') return;

    // The redirect server tags Stage-1 → cname redirects with `lgr_cid` so the
    // app can correlate to the existing Click. Pull it out of the incoming
    // params before they're forwarded; passing it through to the host app's
    // router would leak an internal id.
    final lgrCid = params['lgr_cid'];
    final forwardedParams = lgrCid == null
        ? params
        : (Map<String, String>.from(params)..remove('lgr_cid'));

    if (isResolved) {
      final finalPath = _appendQueryParams(path, forwardedParams);
      LinkGravityLogger.info('✅ Pre-resolved, navigating: $finalPath');
      _globalOnNavigate!(finalPath);
      return;
    }

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;
    final shortCode = segments.last;

    final isHttp = link.startsWith('http://') || link.startsWith('https://');

    // Host gating: when `config.linkHosts` is non-empty, only http(s) URLs
    // whose host is in the list are resolved against the backend. Foreign
    // hosts are passed straight to the router — they're not our short links.
    if (isHttp && config.linkHosts.isNotEmpty) {
      final host = Uri.tryParse(link)?.host ?? '';
      if (!config.linkHosts.contains(host)) {
        LinkGravityLogger.info('🔀 Foreign host, pass-through: $link');
        _globalOnNavigate?.call(link);
        return;
      }
    }

    // Click-attribution discriminator: only one of source / cid is set.
    //   - deferred match → already counted before install, send neither
    //   - lgr_cid present → server already counted, send cid for correlation
    //   - http(s) link → server bypassed by the OS, send source
    //   - custom scheme → server already counted (smart-redirect page), send
    //     neither
    String? source;
    String? cid;
    if (isFromDeferredMatch) {
      // intentionally both null
    } else if (lgrCid != null) {
      cid = lgrCid;
    } else if (isHttp) {
      final platformLabel = config.platformOverride ??
          (Platform.isIOS ? 'ios' : 'android');
      source = platformLabel == 'ios'
          ? 'ios_universal_link'
          : 'android_app_link';
    }

    // Fingerprint is only meaningful for the source-counting path (used by
    // the backend's 5-minute dedup key). Skip the device-info round-trip
    // otherwise.
    final fingerprint = source != null
        ? await _fingerprint.generateFingerprint()
        : null;

    LinkGravityLogger.info('🔍 Resolving: $shortCode');

    try {
      final result = await resolveShortCode(
        shortCode,
        source: source,
        cid: cid,
        fingerprint: fingerprint,
      );

      String finalPath;
      if (result != null && result['success'] == true) {
        // Backend returns `route` as a plain path (e.g. "/details") — use it
        // verbatim and append any incoming query params (lgr_cid stripped).
        final route = result['route'] as String;
        finalPath = _appendQueryParams(route, forwardedParams);

        final utm = result['utm'] as Map<String, dynamic>?;
        if (utm != null) {
          try {
            setUTM(UTMParams.fromJson(utm));
          } catch (_) {}
        }
      } else {
        LinkGravityLogger.warning('⚠️ Resolution failed for: $shortCode');
        finalPath = _appendQueryParams(path, forwardedParams);
      }

      LinkGravityLogger.info('🚀 Navigating: $finalPath');
      _globalOnNavigate?.call(finalPath);
    } catch (e, stack) {
      LinkGravityLogger.error('❌ Error resolving link', e, stack);
    }
  }

  /// Split a raw link into (path, queryParameters).
  ///
  /// For HTTP(S) URLs the host is stripped. For custom-scheme URIs (e.g.
  /// `myapp://details`) the host becomes the first path segment.
  static (String, Map<String, String>) _splitLink(String link) {
    final uri = link.contains('://')
        ? Uri.parse(link)
        : Uri.parse(
            'http://x.invalid${link.startsWith('/') ? link : '/$link'}',
          );

    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    final path = (!isHttp && uri.host.isNotEmpty)
        ? '/${uri.host}${uri.path}'
        : uri.path;

    return (path, uri.queryParameters);
  }

  static String _appendQueryParams(String path, Map<String, String> params) {
    if (params.isEmpty) return path;
    final separator = path.contains('?') ? '&' : '?';
    final encoded = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$path$separator$encoded';
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Track a custom analytics event
  ///
  /// Example:
  /// ```dart
  /// await linkGravity.trackEvent('purchase', {
  ///   'productId': '123',
  ///   'amount': 29.99,
  ///   'currency': 'USD',
  /// });
  /// ```
  Future<void> trackEvent(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {
    _ensureInitialized();

    if (!config.enableAnalytics) {
      LinkGravityLogger.debug('Analytics disabled');
      return;
    }

    // Merge global metadata
    final mergedProperties = {...?config.globalMetadata, ...?properties};

    await _analytics.trackEvent(eventName, mergedProperties);
  }

  /// Track a conversion event (purchase, signup, etc.)
  ///
  /// Use this to track valuable user actions for attribution analysis.
  ///
  /// Example:
  /// ```dart
  /// await linkGravity.trackConversion(
  ///   type: 'purchase',
  ///   revenue: 29.99,
  ///   currency: 'USD',
  ///   linkId: 'abc123', // Optional: associate with a specific link
  /// );
  /// ```
  ///
  /// Parameters:
  /// - [type]: Type of conversion (e.g., 'purchase', 'signup', 'subscription')
  /// - [revenue]: Revenue amount (optional)
  /// - [currency]: Currency code (default: 'USD')
  /// - [linkId]: Associated link ID for attribution (optional)
  /// - [metadata]: Additional conversion data (optional)
  Future<bool> trackConversion({
    required String type,
    double? revenue,
    String currency = 'USD',
    String? linkId,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    final success = await _api.trackConversion(
      type: type,
      revenue: revenue,
      currency: currency,
      linkId: linkId,
      metadata: metadata,
    );

    if (success) {
      LinkGravityLogger.info(
        'Conversion tracked: $type${revenue != null ? ' ($revenue $currency)' : ''}',
      );
    }

    return success;
  }

  /// Manually flush pending analytics events
  Future<void> flushEvents() async {
    _ensureInitialized();
    await _analytics.flush();
  }

  // ============================================================================
  // ATTRIBUTION
  // ============================================================================

  /// Get attribution data for this user/device
  ///
  /// Returns cached attribution if available, otherwise fetches from backend.
  Future<AttributionData?> getAttribution() async {
    _ensureInitialized();

    // Cache-only, and the cache is written by the deferred-match flow above.
    //
    // This used to fall back to GET /api/v1/sdk/deferred-link, which is not a route — and
    // could not have worked if it were: it matches on `DeferredLink.fingerprint`, which the
    // redirect server derives from HTTP request data, against a hash this SDK computes on
    // the device from device attributes. Two unrelated values that can never be equal.
    // Probabilistic matching lives in /sdk/match, which the deferred flow already uses.
    final attribution = await _storage.getAttribution();

    if (attribution == null) {
      LinkGravityLogger.debug(
        'No attribution stored — this install was organic, or the deferred match has not '
        'run yet (it runs once, on first launch after install).',
      );
    }

    return attribution;
  }

  // ============================================================================
  // USER MANAGEMENT
  // ============================================================================

  /// Set user ID for attribution
  ///
  /// Call this after user logs in to link events to a specific user.
  Future<void> setUserId(String userId) async {
    _ensureInitialized();
    await _analytics.setUserId(userId);
    LinkGravityLogger.info('User ID set: $userId');
  }

  /// Clear user ID (e.g., on logout)
  Future<void> clearUserId() async {
    _ensureInitialized();
    await _analytics.setUserId(null);
    LinkGravityLogger.info('User ID cleared');
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  /// Get device fingerprint
  String? get fingerprint => _deviceFingerprint;

  /// Get device ID
  String? get deviceId => _deviceId;

  /// Get app version
  String? get appVersion => _appVersion;

  /// Get current session ID
  String? get sessionId => _analytics.sessionId;

  /// Check if SDK is initialized
  bool get isInitialized => _initialized;

  /// Get failed events count (offline queue)
  Future<int> getFailedEventsCount() async {
    return await _analytics.getFailedEventsCount();
  }

  // ============================================================================
  // UTM ATTRIBUTION
  // ============================================================================

  /// Get UTM parameters from Android Install Referrer (Android only)
  ///
  /// Returns UTM parameters extracted from the Play Store Install Referrer.
  /// Only available on Android devices and only after the install referrer
  /// has been retrieved (happens automatically on first app launch).
  ///
  /// Returns empty UTMParams if:
  /// - Device is not Android
  /// - Install referrer hasn't been retrieved yet
  /// - Install referrer contains no UTM parameters
  ///
  /// Example:
  /// ```dart
  /// final utm = linkGravity.getInstallReferrerUTM();
  /// if (utm.isNotEmpty) {
  ///   print('Installed from: ${utm.source}');
  ///   print('Campaign: ${utm.campaign}');
  /// }
  /// ```
  UTMParams getInstallReferrerUTM() {
    return _installReferrer.getUTMParams();
  }

  /// Get cached UTM parameters from install (persistent)
  ///
  /// Retrieves UTM parameters that were stored when the app was installed.
  /// These remain available even after app restarts.
  ///
  /// Returns null if no cached UTM parameters are found.
  ///
  /// Example:
  /// ```dart
  /// final utm = await linkGravity.getCachedInstallUTM();
  /// if (utm != null) {
  ///   print('Original install source: ${utm.source}');
  ///   print('Original campaign: ${utm.campaign}');
  /// }
  /// ```
  Future<UTMParams?> getCachedInstallUTM() async {
    return await _installReferrer.getCachedInstallUTM();
  }

  /// Get current UTM attribution parameters
  ///
  /// Returns the UTM parameters that are currently being auto-attached
  /// to all analytics events. This is typically the install UTM from the
  /// Play Store Install Referrer (Android) or deferred deep link (iOS).
  ///
  /// Returns null if no UTM attribution is active.
  ///
  /// Example:
  /// ```dart
  /// final utm = linkGravity.currentUTM;
  /// if (utm != null) {
  ///   print('Current attribution: ${utm.source} / ${utm.campaign}');
  /// }
  /// ```
  UTMParams? get currentUTM => _analytics.cachedUTM;

  /// Set custom UTM parameters for attribution
  ///
  /// Override the automatic install UTM with custom values.
  /// This affects all future analytics events until changed or cleared.
  ///
  /// Use cases:
  /// - Attribute events to a re-engagement campaign
  /// - Track events from an email link click
  /// - Custom attribution for specific user flows
  ///
  /// Pass null to clear and revert to install UTM.
  ///
  /// Example:
  /// ```dart
  /// // Set custom UTM for email campaign
  /// linkGravity.setUTM(UTMParams(
  ///   source: 'email',
  ///   campaign: 'summer-2024',
  ///   medium: 'newsletter',
  /// ));
  ///
  /// // Track events with this attribution
  /// await linkGravity.trackEvent('purchase', {'amount': 99.99});
  ///
  /// // Clear custom UTM (revert to install UTM)
  /// linkGravity.setUTM(null);
  /// ```
  void setUTM(UTMParams? utm) {
    _analytics.setUTM(utm);
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Ensure SDK is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'LinkGravity not initialized. Call LinkGravityClient.initialize() first.',
      );
    }
  }

  /// Reset SDK (clear all data)
  ///
  /// WARNING: This will clear all cached data including attribution.
  /// Use with caution!
  Future<void> reset() async {
    LinkGravityLogger.warning('Resetting LinkGravity SDK...');

    await _storage.clearAll();
    await _analytics.clearFailedEvents();

    LinkGravityLogger.info('LinkGravity SDK reset complete');
  }

  /// Dispose SDK resources
  ///
  /// Call this when your app is shutting down.
  Future<void> dispose() async {
    LinkGravityLogger.info('Disposing LinkGravity SDK...');

    await _analytics.dispose();
    _deepLink.dispose();
    _api.dispose();

    _linkSubscription?.cancel();
    _resolvedLinkSubscription?.cancel();
    _globalOnNavigate = null;

    _initialized = false;
    _instance = null;

    LinkGravityLogger.info('LinkGravity SDK disposed');
  }

  // ==========================================
  // iOS Attribution - SKAdNetwork & IDFA/ATT
  // ==========================================

  /// Request tracking authorization from user (iOS only)
  ///
  /// Shows the iOS system prompt asking for permission to track.
  /// Only available on iOS 14.0+
  ///
  /// **Important:**
  /// - Add `NSUserTrackingUsageDescription` to your Info.plist
  /// - This should be called at an appropriate moment when user understands the value
  /// - Can only be requested once per app installation
  ///
  /// **Privacy Note:**
  /// IDFA collection is completely optional. By default, LinkGravity uses
  /// privacy-first probabilistic attribution. Use this only if you need
  /// deterministic attribution and have proper consent.
  ///
  /// Example:
  /// ```dart
  /// // Check if we should request permission
  /// if (Platform.isIOS) {
  ///   final status = await linkGravity.getTrackingAuthorizationStatus();
  ///   if (status == TrackingAuthorizationStatus.notDetermined) {
  ///     // Good time to show explanation to user, then request
  ///     final newStatus = await linkGravity.requestTrackingAuthorization();
  ///     if (newStatus == TrackingAuthorizationStatus.authorized) {
  ///       print('User granted tracking permission');
  ///     }
  ///   }
  /// }
  /// ```
  Future<TrackingAuthorizationStatus> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      LinkGravityLogger.debug('ATT: Not available on non-iOS platform');
      return TrackingAuthorizationStatus.notDetermined;
    }

    final status = await _idfa.requestTrackingAuthorization();

    // If authorized, collect IDFA and update fingerprint
    if (status == TrackingAuthorizationStatus.authorized) {
      final idfa = await _idfa.getIDFA();
      if (idfa != null) {
        LinkGravityLogger.info(
          'ATT: IDFA collected for deterministic attribution',
        );
        // IDFA will be included in future fingerprint updates
      }
    }

    return status;
  }

  /// Get current tracking authorization status (iOS only)
  ///
  /// Check status without requesting permission
  ///
  /// Example:
  /// ```dart
  /// final status = await linkGravity.getTrackingAuthorizationStatus();
  /// switch (status) {
  ///   case TrackingAuthorizationStatus.authorized:
  ///     print('Tracking authorized');
  ///     break;
  ///   case TrackingAuthorizationStatus.denied:
  ///     print('User denied tracking');
  ///     break;
  ///   case TrackingAuthorizationStatus.notDetermined:
  ///     print('User has not been asked yet');
  ///     break;
  ///   case TrackingAuthorizationStatus.restricted:
  ///     print('Tracking restricted (e.g., parental controls)');
  ///     break;
  /// }
  /// ```
  Future<TrackingAuthorizationStatus> getTrackingAuthorizationStatus() async {
    return _idfa.getTrackingAuthorizationStatus();
  }

  /// Get IDFA if available (iOS only)
  ///
  /// Returns null if user hasn't authorized tracking or IDFA is unavailable
  ///
  /// Example:
  /// ```dart
  /// final idfa = await linkGravity.getIDFA();
  /// if (idfa != null) {
  ///   print('IDFA available for deterministic attribution');
  /// } else {
  ///   print('Using probabilistic attribution');
  /// }
  /// ```
  Future<String?> getIDFA() async {
    return _idfa.getIDFA();
  }

  /// Update SKAdNetwork conversion value (iOS 14.0+)
  ///
  /// Report conversion events to ad networks via SKAdNetwork.
  /// Use this to track in-app events for iOS ad attribution.
  ///
  /// [conversionValue] must be 0-63 (6-bit value)
  ///
  /// **Conversion Value Schema Example:**
  /// - 0-10: Tutorial progress
  /// - 11-20: Feature usage
  /// - 21-40: Purchase events
  /// - 41-63: LTV tiers
  ///
  /// Example:
  /// ```dart
  /// // User completed tutorial
  /// await linkGravity.updateConversionValue(10);
  ///
  /// // User made first purchase
  /// await linkGravity.updateConversionValue(21);
  ///
  /// // User reached high LTV tier
  /// await linkGravity.updateConversionValue(50);
  /// ```
  Future<bool> updateConversionValue(int conversionValue) async {
    if (!Platform.isIOS) {
      LinkGravityLogger.debug('SKAdNetwork: Not available on non-iOS platform');
      return false;
    }

    return _skadnetwork.updateConversionValue(conversionValue);
  }

  /// Update SKAdNetwork postback conversion value (iOS 15.4+)
  ///
  /// Advanced conversion tracking with fine and coarse values.
  /// Provides more granular conversion tracking than basic conversion value.
  ///
  /// [fineValue]: 6-bit fine-grained value (0-63)
  /// [coarseValue]: Coarse conversion value ('low', 'medium', 'high')
  /// [lockWindow]: Whether to lock the conversion window
  ///
  /// Example:
  /// ```dart
  /// // High-value conversion with specific fine value
  /// await linkGravity.updatePostbackConversionValue(
  ///   fineValue: 42,
  ///   coarseValue: 'high',
  ///   lockWindow: false,
  /// );
  ///
  /// // Lock window after critical conversion
  /// await linkGravity.updatePostbackConversionValue(
  ///   fineValue: 63,
  ///   coarseValue: 'high',
  ///   lockWindow: true, // Lock to prevent further updates
  /// );
  /// ```
  Future<bool> updatePostbackConversionValue({
    required int fineValue,
    required String coarseValue,
    bool lockWindow = false,
  }) async {
    if (!Platform.isIOS) {
      LinkGravityLogger.debug('SKAdNetwork: Not available on non-iOS platform');
      return false;
    }

    return _skadnetwork.updatePostbackConversionValue(
      fineValue: fineValue,
      coarseValue: coarseValue,
      lockWindow: lockWindow,
    );
  }

  /// Get SKAdNetwork version available on this device
  ///
  /// Returns version like "4.0", "3.0", "2.2", "2.0", or "Not supported"
  ///
  /// Example:
  /// ```dart
  /// final version = await linkGravity.getSKAdNetworkVersion();
  /// print('SKAdNetwork version: $version');
  ///
  /// if (version == '4.0') {
  ///   // Use advanced features
  ///   await linkGravity.updatePostbackConversionValue(
  ///     fineValue: 42,
  ///     coarseValue: 'high',
  ///   );
  /// } else if (version == '2.0' || version == '3.0') {
  ///   // Use basic conversion value
  ///   await linkGravity.updateConversionValue(42);
  /// }
  /// ```
  Future<String> getSKAdNetworkVersion() async {
    return _skadnetwork.getSKAdNetworkVersion();
  }

  /// Check if SKAdNetwork is available on this device
  ///
  /// Returns true on iOS 14.0+, false otherwise
  Future<bool> isSKAdNetworkAvailable() async {
    return _skadnetwork.isAvailable();
  }

  /// Get comprehensive iOS attribution info for debugging
  ///
  /// Returns information about SKAdNetwork and ATT status
  ///
  /// Example:
  /// ```dart
  /// final info = await linkGravity.getIOSAttributionInfo();
  /// print('SKAdNetwork: ${info['skadnetwork']}');
  /// print('ATT: ${info['att']}');
  /// ```
  Future<Map<String, dynamic>> getIOSAttributionInfo() async {
    if (!Platform.isIOS) {
      return {
        'platform': 'non-iOS',
        'skadnetwork': {'available': false},
        'att': {'available': false},
      };
    }

    final skadConfig = await _skadnetwork.getConfig();
    final attInfo = await _idfa.getTrackingInfo();

    return {'platform': 'iOS', 'skadnetwork': skadConfig, 'att': attInfo};
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'models/link.dart';
import 'models/link_params.dart';
import 'models/attribution.dart';
import 'models/deep_link_data.dart';
import 'models/analytics_event.dart';
import 'models/utm_params.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/fingerprint_service.dart';
import 'services/deep_link_service.dart';
import 'services/deferred_deep_link_service.dart';
import 'services/analytics_service.dart';
import 'services/install_referrer_service.dart';
import 'smartlink_config.dart';
import 'utils/logger.dart';

/// Main SmartLink SDK client
///
/// This is the primary class for integrating SmartLink into your Flutter app.
///
/// Example usage:
/// ```dart
/// // Initialize SDK
/// final smartLink = await SmartLinkClient.initialize(
///   baseUrl: 'https://api.smartlink.io',
///   apiKey: 'your-api-key',
/// );
///
/// // Create a link
/// final link = await smartLink.createLink(
///   LinkParams(longUrl: 'https://example.com/product/123'),
/// );
///
/// // Listen for deep links
/// smartLink.onDeepLink.listen((deepLink) {
///   print('Deep link opened: ${deepLink.path}');
/// });
/// ```
class SmartLinkClient {
  /// Singleton instance
  static SmartLinkClient? _instance;

  /// Get singleton instance (must call [initialize] first)
  static SmartLinkClient get instance {
    if (_instance == null) {
      throw StateError(
        'SmartLink not initialized. Call SmartLinkClient.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Base URL of SmartLink backend
  final String baseUrl;

  /// API Key for authentication
  final String? apiKey;

  /// SDK Configuration
  final SmartLinkConfig config;

  // Services
  late final ApiService _api;
  late final StorageService _storage;
  late final FingerprintService _fingerprint;
  late final DeepLinkService _deepLink;
  late final InstallReferrerService _installReferrer;
  late final AnalyticsService _analytics;

  /// Whether SDK has been initialized
  bool _initialized = false;

  /// Device fingerprint
  String? _deviceFingerprint;

  /// Device ID (Android ID or iOS IDFV)
  String? _deviceId;

  /// App version
  String? _appVersion;

  /// Private constructor
  SmartLinkClient._({
    required this.baseUrl,
    this.apiKey,
    required this.config,
  }) {
    // Initialize logger
    SmartLinkLogger.setLevel(config.logLevel);

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
  }

  /// Initialize the SmartLink SDK
  ///
  /// This must be called before using any other SDK features.
  /// Typically called in your app's main() function or app startup.
  ///
  /// Parameters:
  /// - [baseUrl]: Base URL of your SmartLink backend (e.g., 'https://api.smartlink.io')
  /// - [apiKey]: Your API key (optional for some read-only operations)
  /// - [config]: SDK configuration (optional)
  ///
  /// Returns initialized [SmartLinkClient] instance
  static Future<SmartLinkClient> initialize({
    required String baseUrl,
    String? apiKey,
    SmartLinkConfig? config,
  }) async {
    if (_instance != null) {
      SmartLinkLogger.warning(
          'SmartLink already initialized, returning existing instance');
      return _instance!;
    }

    SmartLinkLogger.info('Initializing SmartLink SDK...');

    _instance = SmartLinkClient._(
      baseUrl: baseUrl,
      apiKey: apiKey,
      config: config ?? SmartLinkConfig(),
    );

    await _instance!._init();

    return _instance!;
  }

  /// Internal initialization
  Future<void> _init() async {
    if (_initialized) return;

    SmartLinkLogger.info('SmartLink SDK ${config.toString()}');

    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      SmartLinkLogger.debug('App version: $_appVersion');

      // Initialize analytics service
      await _analytics.initialize();

      // Generate/retrieve device fingerprint
      _deviceFingerprint = await _storage.getFingerprint();
      if (_deviceFingerprint == null) {
        _deviceFingerprint = await _fingerprint.generateFingerprint();
        await _storage.saveFingerprint(_deviceFingerprint!);
        SmartLinkLogger.info('New device fingerprint generated');
      } else {
        SmartLinkLogger.debug('Existing fingerprint loaded');
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

        SmartLinkLogger.info('Deep linking enabled');
      }

      // Track app open event
      if (config.enableAnalytics) {
        await _trackAppOpen();
      }

      _initialized = true;
      SmartLinkLogger.info('SmartLink SDK initialized successfully');
    } catch (e, stackTrace) {
      SmartLinkLogger.error(
          'Failed to initialize SmartLink SDK', e, stackTrace);
      rethrow;
    }
  }

  /// Handle deferred deep link on first app launch
  ///
  /// Uses the best available matching method:
  /// - Android: Play Install Referrer (deterministic, 100% accuracy) → Fingerprint (fallback)
  /// - iOS: Fingerprint only (probabilistic, ~85-90% accuracy)
  Future<void> _handleDeferredDeepLink() async {
    final isFirstLaunch = await _storage.isFirstLaunch();

    if (!isFirstLaunch) {
      SmartLinkLogger.debug(
          'Not first launch, skipping deferred deep link check');
      return;
    }

    SmartLinkLogger.info(
        'First launch detected, checking for deferred deep link...');

    try {
      // Create deferred deep link service with Android referrer support
      final deferredService = DeferredDeepLinkService(
        apiService: _api,
        fingerprintService: _fingerprint,
      );

      // Try to match using best available method (referrer on Android, fingerprint on iOS)
      // Uses retry logic with exponential backoff for better reliability
      final match = await deferredService.matchDeferredDeepLinkWithRetry();

      if (match != null && match.success && match.deepLinkUrl != null) {
        SmartLinkLogger.info('✅ Deferred deep link found!');
        SmartLinkLogger.info('   Method: ${match.matchMethod}');
        SmartLinkLogger.info('   URL: ${match.deepLinkUrl}');

        // Track install with attribution
        await _api.trackInstall(
          fingerprint: _deviceFingerprint,
          deviceId: _deviceId,
          platform: await _fingerprint.getPlatformName(),
          appVersion: _appVersion,
          deferredLinkId: match.linkId,
          matchMethod: match.matchMethod,
          matchConfidence: match.confidence,
          matchScore: match.score?.toDouble(),
        );

        // Track deferred link opened event
        await _analytics.trackEvent(
          EventType.deferredLinkOpened,
          {
            'linkId': match.linkId,
            'shortCode': match.shortCode,
            'matchMethod': match.matchMethod,
            'deepLinkUrl': match.deepLinkUrl,
            ...?match.params,
          },
        );

        // Emit deep link event
        final uri = Uri.parse(match.deepLinkUrl!);
        final deepLink = _deepLink.parseLink(uri);

        // Set as initial link so it's available via initialDeepLink getter
        // This allows the app to check for deferred links after initialization
        _deepLink.initialLink = deepLink;

        _deepLink.linkController.add(deepLink);
      } else {
        SmartLinkLogger.debug('No deferred deep link found');
      }
    } catch (e, stackTrace) {
      SmartLinkLogger.error('Error handling deferred deep link', e, stackTrace);
    }

    // Mark as launched (even if matching failed)
    await _storage.markAsLaunched();
  }

  /// Track app open event
  Future<void> _trackAppOpen() async {
    await _analytics.trackEvent(
      EventType.appOpened,
      {
        'appVersion': _appVersion,
        'platform': await _fingerprint.getPlatformName(),
        'deviceModel': await _fingerprint.getDeviceModel(),
        'osVersion': await _fingerprint.getOSVersion(),
        'isPhysicalDevice': await _fingerprint.isPhysicalDevice(),
        ...?config.globalMetadata,
      },
    );
  }

  // ============================================================================
  // LINK MANAGEMENT
  // ============================================================================

  /// Create a new SmartLink
  ///
  /// Example:
  /// ```dart
  /// final link = await smartLink.createLink(
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
  Future<SmartLink> createLink(LinkParams params) async {
    _ensureInitialized();

    SmartLinkLogger.info('Creating link: ${params.longUrl}');
    final link = await _api.createLink(params);

    // Track link created event
    if (config.enableAnalytics) {
      await _analytics.trackEvent(
        EventType.linkCreated,
        {
          'linkId': link.id,
          'shortCode': link.shortCode,
          'longUrl': link.longUrl,
        },
      );
    }

    return link;
  }

  /// Get a specific link by ID
  Future<SmartLink> getLink(String linkId) async {
    _ensureInitialized();
    return await _api.getLink(linkId);
  }

  /// Get all links
  Future<List<SmartLink>> getLinks(
      {int? limit, int? offset, String? search}) async {
    _ensureInitialized();
    return await _api.getLinks(limit: limit, offset: offset, search: search);
  }

  /// Update an existing link
  Future<SmartLink> updateLink(String linkId, LinkParams params) async {
    _ensureInitialized();
    return await _api.updateLink(linkId, params);
  }

  /// Delete a link
  Future<void> deleteLink(String linkId) async {
    _ensureInitialized();
    await _api.deleteLink(linkId);
  }

  // ============================================================================
  // DEEP LINKING
  // ============================================================================

  /// Stream of incoming deep links
  ///
  /// Listen to this stream to handle deep links in your app.
  ///
  /// Example:
  /// ```dart
  /// smartLink.onDeepLink.listen((deepLink) {
  ///   if (deepLink.path.startsWith('/product/')) {
  ///     final productId = deepLink.path.split('/').last;
  ///     navigateToProduct(productId);
  ///   }
  /// });
  /// ```
  Stream<DeepLinkData> get onDeepLink => _deepLink.linkStream;

  /// Get initial deep link (if app was opened via deep link)
  DeepLinkData? get initialDeepLink => _deepLink.initialLink;

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Track a custom analytics event
  ///
  /// Example:
  /// ```dart
  /// await smartLink.trackEvent('purchase', {
  ///   'productId': '123',
  ///   'amount': 29.99,
  ///   'currency': 'USD',
  /// });
  /// ```
  Future<void> trackEvent(String eventName,
      [Map<String, dynamic>? properties]) async {
    _ensureInitialized();

    if (!config.enableAnalytics) {
      SmartLinkLogger.debug('Analytics disabled');
      return;
    }

    // Merge global metadata
    final mergedProperties = {
      ...?config.globalMetadata,
      ...?properties,
    };

    await _analytics.trackEvent(eventName, mergedProperties);
  }

  /// Track a conversion event (purchase, signup, etc.)
  ///
  /// Use this to track valuable user actions for attribution analysis.
  ///
  /// Example:
  /// ```dart
  /// await smartLink.trackConversion(
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
      SmartLinkLogger.info(
          'Conversion tracked: $type${revenue != null ? ' ($revenue $currency)' : ''}');
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

    // Check cache first
    var attribution = await _storage.getAttribution();
    if (attribution != null) {
      SmartLinkLogger.debug('Returning cached attribution');
      return attribution;
    }

    // Fetch from backend
    attribution = await _api.getDeferredLink(_deviceFingerprint!);
    if (attribution != null) {
      await _storage.saveAttribution(attribution);
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
    SmartLinkLogger.info('User ID set: $userId');
  }

  /// Clear user ID (e.g., on logout)
  Future<void> clearUserId() async {
    _ensureInitialized();
    await _analytics.setUserId(null);
    SmartLinkLogger.info('User ID cleared');
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
  /// final utm = smartLink.getInstallReferrerUTM();
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
  /// final utm = await smartLink.getCachedInstallUTM();
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
  /// final utm = smartLink.currentUTM;
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
  /// smartLink.setUTM(UTMParams(
  ///   source: 'email',
  ///   campaign: 'summer-2024',
  ///   medium: 'newsletter',
  /// ));
  ///
  /// // Track events with this attribution
  /// await smartLink.trackEvent('purchase', {'amount': 99.99});
  ///
  /// // Clear custom UTM (revert to install UTM)
  /// smartLink.setUTM(null);
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
        'SmartLink not initialized. Call SmartLinkClient.initialize() first.',
      );
    }
  }

  /// Handle deferred deep linking manually
  ///
  /// Call this on app launch to detect if this is a deferred deep link installation.
  /// The SDK will use the best available matching method:
  /// - Android: Play Install Referrer (100% accuracy) → Fingerprint fallback
  /// - iOS: Fingerprint matching (~85-90% accuracy)
  ///
  /// Parameters:
  /// - [onFound]: Callback when a deferred deep link is found
  /// - [onNotFound]: Optional callback when no deferred deep link is found
  ///
  /// Returns the matched deep link URL if found, null otherwise.
  Future<String?> handleDeferredDeepLink({
    required VoidCallback onFound,
    VoidCallback? onNotFound,
  }) async {
    if (!_initialized) {
      SmartLinkLogger.error('SmartLink not initialized');
      onNotFound?.call();
      return null;
    }

    try {
      SmartLinkLogger.info('Handling deferred deep link...');

      final deferredService = DeferredDeepLinkService(
        apiService: _api,
        fingerprintService: _fingerprint,
      );

      // Use the new method that supports Android referrer
      final match = await deferredService.matchDeferredDeepLink();

      if (match != null && match.success && match.deepLinkUrl != null) {
        SmartLinkLogger.info(
            '✅ Deferred deep link found: ${match.deepLinkUrl}');
        SmartLinkLogger.info('   Method: ${match.matchMethod}');

        // Check confidence for fingerprint matches
        if (match.isAcceptableConfidence()) {
          onFound();

          // Track the install with deferred link data
          await _api.trackInstall(
            fingerprint: _deviceFingerprint,
            deviceId: _deviceId,
            platform: await _fingerprint.getPlatformName(),
            appVersion: _appVersion,
            deferredLinkId: match.linkId,
            matchMethod: match.matchMethod,
            matchConfidence: match.confidence,
            matchScore: match.score?.toDouble(),
          );

          return match.deepLinkUrl;
        } else {
          SmartLinkLogger.warning(
              '⚠️ Deep link confidence too low: ${match.confidence}');
          onNotFound?.call();
          return null;
        }
      } else {
        SmartLinkLogger.info('ℹ️ No deferred deep link found');
        onNotFound?.call();
        return null;
      }
    } catch (e) {
      SmartLinkLogger.error('Error handling deferred deep link: $e', e);
      onNotFound?.call();
      return null;
    }
  }

  /// Track app installation
  ///
  /// Call this after app is launched to track the installation.
  /// Optionally include deferred link matching data.
  ///
  /// Parameters:
  /// - [deferredLinkId]: ID of matched deferred link (if any)
  /// - [matchMethod]: How the deferred link was matched ('referrer' or 'fingerprint')
  /// - [matchConfidence]: Confidence level of the match
  /// - [matchScore]: Numeric score of the match
  Future<bool> trackInstall({
    String? deferredLinkId,
    String? matchMethod,
    String? matchConfidence,
    double? matchScore,
  }) async {
    if (!_initialized) {
      SmartLinkLogger.error('SmartLink not initialized');
      return false;
    }

    return _api.trackInstall(
      fingerprint: _deviceFingerprint,
      deviceId: _deviceId,
      platform: await _fingerprint.getPlatformName(),
      appVersion: _appVersion,
      deferredLinkId: deferredLinkId,
      matchMethod: matchMethod,
      matchConfidence: matchConfidence,
      matchScore: matchScore,
    );
  }

  /// Reset SDK (clear all data)
  ///
  /// WARNING: This will clear all cached data including attribution.
  /// Use with caution!
  Future<void> reset() async {
    SmartLinkLogger.warning('Resetting SmartLink SDK...');

    await _storage.clearAll();
    await _analytics.clearFailedEvents();

    SmartLinkLogger.info('SmartLink SDK reset complete');
  }

  /// Dispose SDK resources
  ///
  /// Call this when your app is shutting down.
  Future<void> dispose() async {
    SmartLinkLogger.info('Disposing SmartLink SDK...');

    await _analytics.dispose();
    _deepLink.dispose();
    _api.dispose();

    _initialized = false;
    _instance = null;

    SmartLinkLogger.info('SmartLink SDK disposed');
  }
}

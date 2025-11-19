import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'models/link.dart';
import 'models/link_params.dart';
import 'models/attribution.dart';
import 'models/deep_link_data.dart';
import 'models/analytics_event.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'services/fingerprint_service.dart';
import 'services/deep_link_service.dart';
import 'services/analytics_service.dart';
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
    _analytics = AnalyticsService(
      api: _api,
      storage: _storage,
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
      SmartLinkLogger.warning('SmartLink already initialized, returning existing instance');
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
      SmartLinkLogger.error('Failed to initialize SmartLink SDK', e, stackTrace);
      rethrow;
    }
  }

  /// Handle deferred deep link on first app launch
  Future<void> _handleDeferredDeepLink() async {
    final isFirstLaunch = await _storage.isFirstLaunch();

    if (isFirstLaunch) {
      SmartLinkLogger.info('First launch detected, checking for deferred deep link...');

      // Query backend for deferred link using fingerprint
      final attribution = await _api.getDeferredLink(_deviceFingerprint!);

      if (attribution != null) {
        SmartLinkLogger.info('Deferred deep link found: ${attribution.deferredLink}');

        // Save attribution
        await _storage.saveAttribution(attribution);

        // Track install
        await _api.trackInstall(
          fingerprint: _deviceFingerprint!,
          deviceId: _deviceId!,
          platform: await _fingerprint.getPlatformName(),
          appVersion: _appVersion,
        );

        // Track deferred link opened event
        await _analytics.trackEvent(
          EventType.deferredLinkOpened,
          {
            'linkId': attribution.linkId,
            'deepLinkPath': attribution.deepLinkPath,
            ...?attribution.customData,
          },
        );

        // Emit deep link event if there's a deep link path
        if (attribution.deferredLink != null) {
          final uri = Uri.parse(attribution.deferredLink!);
          final deepLink = _deepLink.parseLink(uri);
          _deepLink.linkController.add(deepLink);
        }
      } else {
        SmartLinkLogger.debug('No deferred deep link found');
      }

      // Mark as launched
      await _storage.markAsLaunched();
    }
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
  Future<List<SmartLink>> getLinks({int? limit, int? offset, String? search}) async {
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
  Future<void> trackEvent(String eventName, [Map<String, dynamic>? properties]) async {
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
  /// Example:
  /// ```dart
  /// await smartLink.trackConversion(
  ///   type: 'purchase',
  ///   revenue: 29.99,
  ///   currency: 'USD',
  /// );
  /// ```
  Future<void> trackConversion({
    required String type,
    required double revenue,
    String currency = 'USD',
    String? linkId,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    await _api.trackConversion(
      type: type,
      revenue: revenue,
      currency: currency,
      linkId: linkId,
      metadata: metadata,
    );

    SmartLinkLogger.info('Conversion tracked: $type ($revenue $currency)');
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

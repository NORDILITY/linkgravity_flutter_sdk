import 'utils/logger.dart';

/// Configuration for LinkGravity SDK
class LinkGravityConfig {
  /// Enable analytics tracking
  final bool enableAnalytics;

  /// Enable deep linking functionality
  final bool enableDeepLinking;

  /// Enable offline event queue
  final bool enableOfflineQueue;

  /// Enable automatic short code resolution
  ///
  /// When enabled, the SDK will automatically attempt to resolve deep link paths
  /// as short codes via the backend API before matching against registered routes.
  ///
  /// This means you don't need custom resolution logic in your app - the SDK
  /// handles it automatically.
  ///
  /// Example: User clicks `http://yourdomain.com/abc123`
  /// - SDK extracts `abc123` as short code
  /// - Calls `/api/v1/sdk/resolve/abc123`
  /// - Gets back `{route: '/product/123'}`
  /// - Navigates to the resolved route
  final bool enableAutoResolution;

  /// Batch size for analytics events
  final int batchSize;

  /// Timeout before sending batched events
  final Duration batchTimeout;

  /// Logging level
  final LogLevel logLevel;

  /// Request timeout for API calls
  final Duration requestTimeout;

  /// Whether to automatically track app lifecycle events
  final bool trackLifecycleEvents;

  /// Custom metadata to include with all events
  final Map<String, dynamic>? globalMetadata;

  /// Debug: Simulate first launch behaviour on every app start
  ///
  /// CAUTION: Do not use in production. It forces the SDK to query the backend
  /// for deferred links on every launch, potentially consuming API limits.
  final bool debugSimulateFirstLaunch;

  LinkGravityConfig({
    this.enableAnalytics = true,
    this.enableDeepLinking = true,
    this.enableOfflineQueue = true,
    this.enableAutoResolution = false,
    this.batchSize = 20,
    this.batchTimeout = const Duration(seconds: 30),
    this.logLevel = LogLevel.info,
    this.requestTimeout = const Duration(seconds: 30),
    this.trackLifecycleEvents = true,
    this.globalMetadata,
    this.debugSimulateFirstLaunch = false,
  }) {
    // Validate configuration
    assert(
      batchSize > 0 && batchSize <= 100,
      'Batch size must be between 1 and 100',
    );
    assert(
      batchTimeout.inMilliseconds >= 1000,
      'Batch timeout must be at least 1 second',
    );
  }

  /// Create a copy with updated values
  LinkGravityConfig copyWith({
    bool? enableAnalytics,
    bool? enableDeepLinking,
    bool? enableOfflineQueue,
    bool? enableAutoResolution,
    int? batchSize,
    Duration? batchTimeout,
    LogLevel? logLevel,
    Duration? requestTimeout,
    bool? trackLifecycleEvents,
    Map<String, dynamic>? globalMetadata,
    bool? debugSimulateFirstLaunch,
  }) {
    return LinkGravityConfig(
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableDeepLinking: enableDeepLinking ?? this.enableDeepLinking,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
      enableAutoResolution: enableAutoResolution ?? this.enableAutoResolution,
      batchSize: batchSize ?? this.batchSize,
      batchTimeout: batchTimeout ?? this.batchTimeout,
      logLevel: logLevel ?? this.logLevel,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      trackLifecycleEvents: trackLifecycleEvents ?? this.trackLifecycleEvents,
      globalMetadata: globalMetadata ?? this.globalMetadata,
      debugSimulateFirstLaunch:
          debugSimulateFirstLaunch ?? this.debugSimulateFirstLaunch,
    );
  }

  @override
  String toString() {
    return 'LinkGravityConfig('
        'enableAnalytics: $enableAnalytics, '
        'enableDeepLinking: $enableDeepLinking, '
        'enableOfflineQueue: $enableOfflineQueue, '
        'enableAutoResolution: $enableAutoResolution, '
        'batchSize: $batchSize, '
        'batchTimeout: $batchTimeout, '
        'logLevel: $logLevel, '
        'debugSimulateFirstLaunch: $debugSimulateFirstLaunch'
        ')';
  }
}

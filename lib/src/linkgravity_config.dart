import 'utils/logger.dart';

/// Configuration for LinkGravity SDK
class LinkGravityConfig {
  /// Enable analytics tracking
  final bool enableAnalytics;

  /// Enable deep linking functionality
  final bool enableDeepLinking;

  /// Enable offline event queue
  final bool enableOfflineQueue;

  /// Batch size for analytics events
  final int batchSize;

  /// Timeout before sending batched events
  final Duration batchTimeout;

  /// Logging level
  final LogLevel logLevel;

  /// Request timeout for API calls
  final Duration requestTimeout;

  /// Custom metadata to include with all events
  final Map<String, dynamic>? globalMetadata;

  /// Debug: Simulate first launch behaviour on every app start
  ///
  /// CAUTION: Do not use in production. It forces the SDK to query the backend
  /// for deferred links on every launch, potentially consuming API limits.
  final bool debugSimulateFirstLaunch;

  /// Hosts that this SDK should treat as LinkGravity short-link hosts.
  ///
  /// When non-empty, `processDeepLink` only calls `/resolve` for incoming
  /// http(s) URLs whose host is in this list. URLs with foreign hosts are
  /// passed straight through to `onNavigate` so the app router can handle
  /// them. When the list is empty (default), every http(s) link is resolved
  /// (legacy behavior).
  final List<String> linkHosts;

  /// Test seam: forces the SDK to behave as if running on the given platform
  /// when computing the click-attribution `source` query parameter.
  ///
  /// Accepted values: `'ios'`, `'android'`, or `null` (default — use
  /// `Platform.isIOS` / `Platform.isAndroid`). Production code should leave
  /// this null; the host platform is the source of truth.
  final String? platformOverride;

  LinkGravityConfig({
    this.enableAnalytics = true,
    this.enableDeepLinking = true,
    this.enableOfflineQueue = true,
    this.batchSize = 20,
    this.batchTimeout = const Duration(seconds: 30),
    this.logLevel = LogLevel.info,
    this.requestTimeout = const Duration(seconds: 30),
    this.globalMetadata,
    this.debugSimulateFirstLaunch = false,
    this.linkHosts = const [],
    this.platformOverride,
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
    int? batchSize,
    Duration? batchTimeout,
    LogLevel? logLevel,
    Duration? requestTimeout,
    Map<String, dynamic>? globalMetadata,
    bool? debugSimulateFirstLaunch,
    List<String>? linkHosts,
    String? platformOverride,
  }) {
    return LinkGravityConfig(
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableDeepLinking: enableDeepLinking ?? this.enableDeepLinking,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
      batchSize: batchSize ?? this.batchSize,
      batchTimeout: batchTimeout ?? this.batchTimeout,
      logLevel: logLevel ?? this.logLevel,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      globalMetadata: globalMetadata ?? this.globalMetadata,
      debugSimulateFirstLaunch:
          debugSimulateFirstLaunch ?? this.debugSimulateFirstLaunch,
      linkHosts: linkHosts ?? this.linkHosts,
      platformOverride: platformOverride ?? this.platformOverride,
    );
  }

  @override
  String toString() {
    return 'LinkGravityConfig('
        'enableAnalytics: $enableAnalytics, '
        'enableDeepLinking: $enableDeepLinking, '
        'enableOfflineQueue: $enableOfflineQueue, '
        'batchSize: $batchSize, '
        'batchTimeout: $batchTimeout, '
        'logLevel: $logLevel, '
        'debugSimulateFirstLaunch: $debugSimulateFirstLaunch'
        ')';
  }
}

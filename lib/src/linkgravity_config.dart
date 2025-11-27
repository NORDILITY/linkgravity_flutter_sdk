import 'utils/logger.dart';

/// Configuration for SmartLink SDK
class SmartLinkConfig {
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

  /// Whether to automatically track app lifecycle events
  final bool trackLifecycleEvents;

  /// Custom metadata to include with all events
  final Map<String, dynamic>? globalMetadata;

  SmartLinkConfig({
    this.enableAnalytics = true,
    this.enableDeepLinking = true,
    this.enableOfflineQueue = true,
    this.batchSize = 20,
    this.batchTimeout = const Duration(seconds: 30),
    this.logLevel = LogLevel.info,
    this.requestTimeout = const Duration(seconds: 30),
    this.trackLifecycleEvents = true,
    this.globalMetadata,
  }) {
    // Validate configuration
    assert(batchSize > 0 && batchSize <= 100,
        'Batch size must be between 1 and 100');
    assert(
      batchTimeout.inMilliseconds >= 1000,
      'Batch timeout must be at least 1 second',
    );
  }

  /// Create a copy with updated values
  SmartLinkConfig copyWith({
    bool? enableAnalytics,
    bool? enableDeepLinking,
    bool? enableOfflineQueue,
    int? batchSize,
    Duration? batchTimeout,
    LogLevel? logLevel,
    Duration? requestTimeout,
    bool? trackLifecycleEvents,
    Map<String, dynamic>? globalMetadata,
  }) {
    return SmartLinkConfig(
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableDeepLinking: enableDeepLinking ?? this.enableDeepLinking,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
      batchSize: batchSize ?? this.batchSize,
      batchTimeout: batchTimeout ?? this.batchTimeout,
      logLevel: logLevel ?? this.logLevel,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      trackLifecycleEvents: trackLifecycleEvents ?? this.trackLifecycleEvents,
      globalMetadata: globalMetadata ?? this.globalMetadata,
    );
  }

  @override
  String toString() {
    return 'SmartLinkConfig('
        'enableAnalytics: $enableAnalytics, '
        'enableDeepLinking: $enableDeepLinking, '
        'enableOfflineQueue: $enableOfflineQueue, '
        'batchSize: $batchSize, '
        'batchTimeout: $batchTimeout, '
        'logLevel: $logLevel'
        ')';
  }
}

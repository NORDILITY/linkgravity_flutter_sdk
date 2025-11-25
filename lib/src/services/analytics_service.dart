import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/analytics_event.dart';
import '../models/utm_params.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'install_referrer_service.dart';
import '../utils/logger.dart';

/// Service for tracking analytics events with batching and offline support
///
/// Automatically attaches UTM parameters to all tracked events for attribution.
class AnalyticsService {
  final ApiService _api;
  final StorageService _storage;
  final InstallReferrerService? _installReferrer;

  /// Queue of events waiting to be sent
  final List<AnalyticsEvent> _eventQueue = [];

  /// Timer for batch flushing
  Timer? _batchTimer;

  /// Batch configuration
  int batchSize;
  Duration batchTimeout;

  /// Whether analytics is enabled
  bool enabled;

  /// Whether offline queueing is enabled
  bool offlineQueueEnabled;

  /// Current session ID
  String? _sessionId;

  /// Current user ID
  String? _userId;

  /// Current device fingerprint
  String? _fingerprint;

  /// Cached UTM parameters from install (for auto-attachment to events)
  UTMParams? _cachedUTM;

  /// Connectivity checker
  final Connectivity _connectivity = Connectivity();

  /// Whether we're currently online
  bool _isOnline = true;

  /// Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  AnalyticsService({
    required ApiService api,
    required StorageService storage,
    InstallReferrerService? installReferrer,
    this.batchSize = 20,
    this.batchTimeout = const Duration(seconds: 30),
    this.enabled = true,
    this.offlineQueueEnabled = true,
  })  : _api = api,
        _storage = storage,
        _installReferrer = installReferrer;

  /// Initialize analytics service
  Future<void> initialize() async {
    SmartLinkLogger.info('Initializing analytics service...');

    // Load cached IDs
    _userId = await _storage.getUserId();
    _fingerprint = await _storage.getFingerprint();

    // Load cached UTM parameters from install (for attribution)
    await _loadCachedUTM();

    // Create new session
    await _startNewSession();

    // Setup connectivity monitoring
    _setupConnectivityMonitoring();

    // Retry failed events from previous sessions
    await _retryFailedEvents();

    SmartLinkLogger.info('Analytics service initialized');
  }

  /// Load cached UTM parameters from install
  ///
  /// These UTM parameters are automatically attached to all tracked events
  /// for attribution to the original marketing campaign.
  Future<void> _loadCachedUTM() async {
    if (_installReferrer != null) {
      _cachedUTM = await _installReferrer!.getCachedInstallUTM();
      if (_cachedUTM != null && _cachedUTM!.isNotEmpty) {
        SmartLinkLogger.info('Loaded install UTM for attribution: $_cachedUTM');
      }
    }
  }

  /// Start a new session
  Future<void> _startNewSession() async {
    _sessionId = const Uuid().v4();
    await _storage.saveSessionId(_sessionId!);
    SmartLinkLogger.debug('New session started: $_sessionId');
  }

  /// Setup connectivity monitoring
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOffline = !_isOnline;
        _isOnline = results.isNotEmpty &&
            results.any((result) => result != ConnectivityResult.none);

        SmartLinkLogger.debug(
            'Connectivity changed: ${_isOnline ? "online" : "offline"}');

        // If we just came online, retry failed events
        if (wasOffline && _isOnline) {
          SmartLinkLogger.info('Connection restored, retrying failed events');
          _retryFailedEvents();
        }
      },
    );

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      SmartLinkLogger.debug(
          'Initial connectivity: ${_isOnline ? "online" : "offline"}');
    });
  }

  /// Track an analytics event
  ///
  /// Automatically attaches UTM parameters from install for attribution.
  /// UTM parameters are added to event properties under the 'utm' key.
  ///
  /// Example:
  /// ```dart
  /// await analytics.trackEvent('purchase', {'amount': 99.99});
  /// // Event will include: {'amount': 99.99, 'utm': {'source': 'facebook', ...}}
  /// ```
  Future<void> trackEvent(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {
    if (!enabled) {
      SmartLinkLogger.debug(
          'Analytics disabled, event not tracked: $eventName');
      return;
    }

    // Merge user properties with auto-attached UTM parameters
    final eventData = <String, dynamic>{
      ...?properties,
      // Auto-attach UTM parameters if available (for attribution)
      if (_cachedUTM != null && _cachedUTM!.isNotEmpty)
        'utm': _cachedUTM!.toJson(),
    };

    final event = AnalyticsEvent(
      id: const Uuid().v4(),
      name: eventName,
      data: eventData,
      timestamp: DateTime.now(),
      userId: _userId,
      sessionId: _sessionId,
      fingerprint: _fingerprint,
    );

    _eventQueue.add(event);
    SmartLinkLogger.debug(
        'Event tracked: $eventName (queue size: ${_eventQueue.length})');

    // Check if we should flush
    if (_eventQueue.length >= batchSize) {
      await flush();
    } else {
      _scheduleBatchFlush();
    }
  }

  /// Set user ID for attribution
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null) {
      await _storage.saveUserId(userId);
      SmartLinkLogger.info('User ID set: $userId');
    } else {
      await _storage.clearUserId();
      SmartLinkLogger.info('User ID cleared');
    }
  }

  /// Set device fingerprint
  void setFingerprint(String fingerprint) {
    _fingerprint = fingerprint;
    SmartLinkLogger.debug('Fingerprint set');
  }

  /// Manually flush event queue
  Future<void> flush() async {
    _batchTimer?.cancel();

    if (_eventQueue.isEmpty) {
      SmartLinkLogger.debug('Event queue is empty, nothing to flush');
      return;
    }

    final events = List<AnalyticsEvent>.from(_eventQueue);
    _eventQueue.clear();

    SmartLinkLogger.info('Flushing ${events.length} events...');

    try {
      if (_isOnline) {
        await _api.sendBatch(events);
        await _storage.saveLastEventSync();
        SmartLinkLogger.info('Successfully sent ${events.length} events');
      } else {
        throw Exception('No internet connection');
      }
    } catch (e) {
      SmartLinkLogger.error('Failed to send events batch', e);

      // Store failed events for retry if offline queue is enabled
      if (offlineQueueEnabled) {
        await _storage.saveFailedEvents(events);
        SmartLinkLogger.info('Saved ${events.length} events to offline queue');
      } else {
        SmartLinkLogger.warning(
            'Offline queue disabled, ${events.length} events lost');
      }
    }
  }

  /// Schedule automatic batch flush
  void _scheduleBatchFlush() {
    _batchTimer?.cancel();
    _batchTimer = Timer(batchTimeout, () {
      SmartLinkLogger.debug('Batch timeout reached, flushing events');
      flush();
    });
  }

  /// Retry failed events from storage
  Future<void> _retryFailedEvents() async {
    if (!offlineQueueEnabled) return;

    final failed = await _storage.getFailedEvents();
    if (failed.isEmpty) return;

    SmartLinkLogger.info('Retrying ${failed.length} failed events...');

    try {
      if (_isOnline) {
        await _api.sendBatch(failed);
        await _storage.clearFailedEvents();
        SmartLinkLogger.info(
            'Successfully sent ${failed.length} failed events');
      } else {
        SmartLinkLogger.debug('Still offline, failed events remain queued');
      }
    } catch (e) {
      SmartLinkLogger.error('Failed to retry events', e);
      // Events remain in storage for next retry
    }
  }

  /// Get failed events count
  Future<int> getFailedEventsCount() async {
    return await _storage.getFailedEventsCount();
  }

  /// Clear all failed events
  Future<void> clearFailedEvents() async {
    await _storage.clearFailedEvents();
    SmartLinkLogger.info('Cleared all failed events');
  }

  /// Get current session ID
  String? get sessionId => _sessionId;

  /// Get current user ID
  String? get userId => _userId;

  /// Get cached UTM parameters
  ///
  /// Returns the UTM parameters that are being auto-attached to all events.
  UTMParams? get cachedUTM => _cachedUTM;

  /// Manually set UTM parameters for attribution
  ///
  /// This overrides the automatically loaded install UTM.
  /// Use this if you want to attribute events to a different campaign
  /// than the original install source.
  ///
  /// Pass null to clear UTM attribution.
  ///
  /// Example:
  /// ```dart
  /// // Set custom UTM for this session
  /// analytics.setUTM(UTMParams(
  ///   source: 'email',
  ///   campaign: 'reactivation-2024',
  /// ));
  ///
  /// // Clear UTM attribution
  /// analytics.setUTM(null);
  /// ```
  void setUTM(UTMParams? utm) {
    _cachedUTM = utm;
    if (utm != null && utm.isNotEmpty) {
      SmartLinkLogger.info('UTM attribution set: $utm');
    } else {
      SmartLinkLogger.info('UTM attribution cleared');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _batchTimer?.cancel();
    _connectivitySubscription?.cancel();

    // Flush remaining events
    if (_eventQueue.isNotEmpty) {
      await flush();
    }

    SmartLinkLogger.debug('AnalyticsService disposed');
  }
}

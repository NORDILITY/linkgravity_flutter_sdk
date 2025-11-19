import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attribution.dart';
import '../models/analytics_event.dart';
import '../utils/logger.dart';

/// Service for local data storage using SharedPreferences
class StorageService {
  // Storage keys
  static const String _keyFingerprint = 'smartlink_fingerprint';
  static const String _keyUserId = 'smartlink_user_id';
  static const String _keyDeviceId = 'smartlink_device_id';
  static const String _keyAttribution = 'smartlink_attribution';
  static const String _keyFailedEvents = 'smartlink_failed_events';
  static const String _keySessionId = 'smartlink_session_id';
  static const String _keyFirstLaunch = 'smartlink_first_launch';
  static const String _keyInstallTimestamp = 'smartlink_install_timestamp';
  static const String _keyLastEventSync = 'smartlink_last_event_sync';

  /// Cached SharedPreferences instance
  SharedPreferences? _prefs;

  /// Get SharedPreferences instance (with caching)
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============================================================================
  // FINGERPRINT
  // ============================================================================

  /// Save device fingerprint
  Future<void> saveFingerprint(String fingerprint) async {
    final prefs = await _preferences;
    await prefs.setString(_keyFingerprint, fingerprint);
    SmartLinkLogger.debug('Fingerprint saved');
  }

  /// Get saved device fingerprint
  Future<String?> getFingerprint() async {
    final prefs = await _preferences;
    return prefs.getString(_keyFingerprint);
  }

  // ============================================================================
  // USER ID
  // ============================================================================

  /// Save user ID for attribution
  Future<void> saveUserId(String userId) async {
    final prefs = await _preferences;
    await prefs.setString(_keyUserId, userId);
    SmartLinkLogger.debug('User ID saved: $userId');
  }

  /// Get saved user ID
  Future<String?> getUserId() async {
    final prefs = await _preferences;
    return prefs.getString(_keyUserId);
  }

  /// Clear user ID (on logout)
  Future<void> clearUserId() async {
    final prefs = await _preferences;
    await prefs.remove(_keyUserId);
    SmartLinkLogger.debug('User ID cleared');
  }

  // ============================================================================
  // DEVICE ID
  // ============================================================================

  /// Save device ID
  Future<void> saveDeviceId(String deviceId) async {
    final prefs = await _preferences;
    await prefs.setString(_keyDeviceId, deviceId);
  }

  /// Get saved device ID
  Future<String?> getDeviceId() async {
    final prefs = await _preferences;
    return prefs.getString(_keyDeviceId);
  }

  // ============================================================================
  // SESSION
  // ============================================================================

  /// Save session ID
  Future<void> saveSessionId(String sessionId) async {
    final prefs = await _preferences;
    await prefs.setString(_keySessionId, sessionId);
  }

  /// Get current session ID
  Future<String?> getSessionId() async {
    final prefs = await _preferences;
    return prefs.getString(_keySessionId);
  }

  /// Clear session ID
  Future<void> clearSessionId() async {
    final prefs = await _preferences;
    await prefs.remove(_keySessionId);
  }

  // ============================================================================
  // ATTRIBUTION
  // ============================================================================

  /// Save attribution data
  Future<void> saveAttribution(AttributionData data) async {
    final prefs = await _preferences;
    await prefs.setString(_keyAttribution, jsonEncode(data.toJson()));
    SmartLinkLogger.debug('Attribution data saved');
  }

  /// Get saved attribution data
  Future<AttributionData?> getAttribution() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_keyAttribution);

      if (json != null) {
        return AttributionData.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      SmartLinkLogger.error('Failed to load attribution data', e);
      return null;
    }
  }

  /// Clear attribution data
  Future<void> clearAttribution() async {
    final prefs = await _preferences;
    await prefs.remove(_keyAttribution);
  }

  // ============================================================================
  // FAILED EVENTS (Offline Queue)
  // ============================================================================

  /// Save events that failed to send (for retry later)
  Future<void> saveFailedEvents(List<AnalyticsEvent> events) async {
    try {
      final prefs = await _preferences;
      final existing = await getFailedEvents();

      // Merge with existing
      existing.addAll(events);

      // Limit queue size (max 1000 events)
      const maxQueueSize = 1000;
      if (existing.length > maxQueueSize) {
        existing.removeRange(0, existing.length - maxQueueSize);
        SmartLinkLogger.warning(
          'Failed events queue exceeded max size, oldest events were dropped',
        );
      }

      // Save to storage
      final eventsJson = existing.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_keyFailedEvents, eventsJson);

      SmartLinkLogger.debug('Saved ${events.length} failed events (total: ${existing.length})');
    } catch (e) {
      SmartLinkLogger.error('Failed to save failed events', e);
    }
  }

  /// Get all failed events from storage
  Future<List<AnalyticsEvent>> getFailedEvents() async {
    try {
      final prefs = await _preferences;
      final eventsJson = prefs.getStringList(_keyFailedEvents) ?? [];

      return eventsJson
          .map((json) => AnalyticsEvent.fromJson(
                jsonDecode(json) as Map<String, dynamic>,
              ))
          .toList();
    } catch (e) {
      SmartLinkLogger.error('Failed to load failed events', e);
      return [];
    }
  }

  /// Clear all failed events
  Future<void> clearFailedEvents() async {
    final prefs = await _preferences;
    await prefs.remove(_keyFailedEvents);
    SmartLinkLogger.debug('Cleared failed events queue');
  }

  /// Get failed events count
  Future<int> getFailedEventsCount() async {
    final events = await getFailedEvents();
    return events.length;
  }

  // ============================================================================
  // FIRST LAUNCH / INSTALL
  // ============================================================================

  /// Check if this is the first launch after install
  Future<bool> isFirstLaunch() async {
    final prefs = await _preferences;
    return !prefs.containsKey(_keyFirstLaunch);
  }

  /// Mark app as launched (called after first launch)
  Future<void> markAsLaunched() async {
    final prefs = await _preferences;
    await prefs.setBool(_keyFirstLaunch, true);
    await prefs.setString(_keyInstallTimestamp, DateTime.now().toIso8601String());
    SmartLinkLogger.info('First launch completed, marked as launched');
  }

  /// Get install timestamp
  Future<DateTime?> getInstallTimestamp() async {
    final prefs = await _preferences;
    final timestamp = prefs.getString(_keyInstallTimestamp);
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  // ============================================================================
  // EVENT SYNC
  // ============================================================================

  /// Save last event sync timestamp
  Future<void> saveLastEventSync() async {
    final prefs = await _preferences;
    await prefs.setString(_keyLastEventSync, DateTime.now().toIso8601String());
  }

  /// Get last event sync timestamp
  Future<DateTime?> getLastEventSync() async {
    final prefs = await _preferences;
    final timestamp = prefs.getString(_keyLastEventSync);
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  // ============================================================================
  // GENERAL
  // ============================================================================

  /// Clear all SmartLink data
  Future<void> clearAll() async {
    final prefs = await _preferences;
    final keys = [
      _keyFingerprint,
      _keyUserId,
      _keyDeviceId,
      _keyAttribution,
      _keyFailedEvents,
      _keySessionId,
      _keyFirstLaunch,
      _keyInstallTimestamp,
      _keyLastEventSync,
    ];

    for (final key in keys) {
      await prefs.remove(key);
    }

    SmartLinkLogger.info('All SmartLink data cleared');
  }

  /// Check if SDK has been initialized before
  Future<bool> hasBeenInitialized() async {
    final fingerprint = await getFingerprint();
    return fingerprint != null;
  }
}

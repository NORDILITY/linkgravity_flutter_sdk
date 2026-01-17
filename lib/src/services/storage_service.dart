import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attribution.dart';
import '../models/analytics_event.dart';
import '../utils/logger.dart';

/// Service for local data storage using SharedPreferences
class StorageService {
  // Storage keys
  static const String _keyFingerprint = 'linkgravity_fingerprint';
  static const String _keyUserId = 'linkgravity_user_id';
  static const String _keyDeviceId = 'linkgravity_device_id';
  static const String _keyAttribution = 'linkgravity_attribution';
  static const String _keyFailedEvents = 'linkgravity_failed_events';
  static const String _keySessionId = 'linkgravity_session_id';
  static const String _keyFirstLaunch = 'linkgravity_first_launch';
  static const String _keyInstallTimestamp = 'linkgravity_install_timestamp';
  static const String _keyLastEventSync = 'linkgravity_last_event_sync';

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
    LinkGravityLogger.debug('Fingerprint saved');
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
    LinkGravityLogger.debug('User ID saved: $userId');
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
    LinkGravityLogger.debug('User ID cleared');
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
    LinkGravityLogger.debug('Attribution data saved');
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
      LinkGravityLogger.error('Failed to load attribution data', e);
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
        LinkGravityLogger.warning(
          'Failed events queue exceeded max size, oldest events were dropped',
        );
      }

      // Save to storage
      final eventsJson = existing.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_keyFailedEvents, eventsJson);

      LinkGravityLogger.debug(
          'Saved ${events.length} failed events (total: ${existing.length})');
    } catch (e) {
      LinkGravityLogger.error('Failed to save failed events', e);
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
      LinkGravityLogger.error('Failed to load failed events', e);
      return [];
    }
  }

  /// Clear all failed events
  Future<void> clearFailedEvents() async {
    final prefs = await _preferences;
    await prefs.remove(_keyFailedEvents);
    LinkGravityLogger.debug('Cleared failed events queue');
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
    final hasKey = prefs.containsKey(_keyFirstLaunch);
    final isFirst = !hasKey;

    LinkGravityLogger.debug(
      'First launch check: $_keyFirstLaunch exists=$hasKey, isFirstLaunch=$isFirst'
    );

    // Debug: Log all LinkGravity keys
    final allKeys = prefs.getKeys().where((key) => key.startsWith('linkgravity_'));
    LinkGravityLogger.debug('All LinkGravity keys in SharedPreferences: ${allKeys.join(", ")}');

    return isFirst;
  }

  /// Mark app as launched (called after first launch)
  Future<void> markAsLaunched() async {
    final prefs = await _preferences;
    await prefs.setBool(_keyFirstLaunch, true);
    await prefs.setString(
        _keyInstallTimestamp, DateTime.now().toIso8601String());
    LinkGravityLogger.info('First launch completed, marked as launched');
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
  // GENERIC DATA STORAGE
  // ============================================================================

  /// Save generic data as JSON
  ///
  /// Stores any JSON-serializable data with the given key.
  /// Used for UTM parameters and other custom data storage needs.
  ///
  /// Example:
  /// ```dart
  /// await storage.saveData('custom_key', {'foo': 'bar'});
  /// ```
  Future<void> saveData(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await _preferences;
      await prefs.setString(key, jsonEncode(data));
      LinkGravityLogger.debug('Data saved for key: $key');
    } catch (e) {
      LinkGravityLogger.error('Failed to save data for key: $key', e);
      rethrow;
    }
  }

  /// Get generic data from JSON
  ///
  /// Retrieves JSON data stored with the given key.
  /// Returns null if the key doesn't exist or if there's an error parsing.
  ///
  /// Example:
  /// ```dart
  /// final data = await storage.getData('custom_key');
  /// if (data != null) {
  ///   print('Value: ${data['foo']}');
  /// }
  /// ```
  Future<Map<String, dynamic>?> getData(String key) async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(key);
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      LinkGravityLogger.error('Failed to load data for key: $key', e);
      return null;
    }
  }

  /// Remove data for a given key
  Future<void> removeData(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
    LinkGravityLogger.debug('Data removed for key: $key');
  }

  // ============================================================================
  // GENERAL
  // ============================================================================

  /// Clear all LinkGravity data
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

    LinkGravityLogger.info('All LinkGravity data cleared');
  }

  /// Check if SDK has been initialized before
  Future<bool> hasBeenInitialized() async {
    final fingerprint = await getFingerprint();
    return fingerprint != null;
  }
}

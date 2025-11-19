/// Represents an analytics event to be tracked
class AnalyticsEvent {
  /// Unique event ID
  final String id;

  /// Event name (e.g., "link_clicked", "app_installed")
  final String name;

  /// Event data/properties
  final Map<String, dynamic> data;

  /// Timestamp when event occurred
  final DateTime timestamp;

  /// User ID if available
  final String? userId;

  /// Session ID
  final String? sessionId;

  /// Device fingerprint
  final String? fingerprint;

  /// Link ID if event is related to a link
  final String? linkId;

  AnalyticsEvent({
    required this.id,
    required this.name,
    required this.data,
    required this.timestamp,
    this.userId,
    this.sessionId,
    this.fingerprint,
    this.linkId,
  });

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
      sessionId: json['sessionId'] as String?,
      fingerprint: json['fingerprint'] as String?,
      linkId: json['linkId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      if (userId != null) 'userId': userId,
      if (sessionId != null) 'sessionId': sessionId,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (linkId != null) 'linkId': linkId,
    };
  }

  @override
  String toString() {
    return 'AnalyticsEvent(id: $id, name: $name, timestamp: $timestamp)';
  }
}

/// Predefined event types
class EventType {
  static const String linkClicked = 'link_clicked';
  static const String linkCreated = 'link_created';
  static const String appInstalled = 'app_installed';
  static const String appOpened = 'app_opened';
  static const String deepLinkOpened = 'deep_link_opened';
  static const String deferredLinkOpened = 'deferred_link_opened';
  static const String screenViewed = 'screen_viewed';
  static const String customEvent = 'custom_event';
}

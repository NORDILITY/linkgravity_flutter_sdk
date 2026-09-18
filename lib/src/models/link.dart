/// Represents a LinkGravity with all its properties
class LinkGravity {
  /// Unique identifier of the link
  final String id;

  /// Short code part of the URL
  final String shortCode;

  /// Full short URL (e.g., https://linkgravity.io/abc123)
  final String shortUrl;

  /// Original long URL
  final String longUrl;

  /// Optional title/description
  final String? title;

  /// Custom metadata as key-value pairs
  final Map<String, dynamic>? metadata;

  /// Optional expiration date
  final DateTime? expiresAt;

  /// Optional start date (link becomes active)
  final DateTime? startsAt;

  /// Whether the link is currently active
  final bool active;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last update timestamp
  final DateTime? updatedAt;

  /// Click count (if available from API)
  final int? clickCount;

  LinkGravity({
    required this.id,
    required this.shortCode,
    required this.shortUrl,
    required this.longUrl,
    this.title,
    this.metadata,
    this.expiresAt,
    this.startsAt,
    this.active = true,
    required this.createdAt,
    this.updatedAt,
    this.clickCount,
  });

  /// Create LinkGravity from JSON response
  factory LinkGravity.fromJson(Map<String, dynamic> json) {
    return LinkGravity(
      // The backend calls the destination `destination`; this package calls it `longUrl`.
      // Reading only `longUrl` meant a successful create still threw while parsing the
      // reply. `shortUrl` is composed by the backend from the link domain — no domain is
      // stored on the row, so the SDK cannot derive it and an empty string is the honest
      // value when an older backend omits it.
      id: json['id'] as String,
      shortCode: json['shortCode'] as String,
      shortUrl: json['shortUrl'] as String? ?? '',
      longUrl: (json['destination'] ?? json['longUrl']) as String,
      title: json['title'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      startsAt: json['startsAt'] != null
          ? DateTime.parse(json['startsAt'] as String)
          : null,
      active: json['active'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      clickCount: json['clickCount'] as int?,
    );
  }

  /// Convert LinkGravity to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shortCode': shortCode,
      'shortUrl': shortUrl,
      'longUrl': longUrl,
      if (title != null) 'title': title,
      if (metadata != null) 'metadata': metadata,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
      'active': active,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (clickCount != null) 'clickCount': clickCount,
    };
  }

  /// Create a copy with updated fields
  LinkGravity copyWith({
    String? id,
    String? shortCode,
    String? shortUrl,
    String? longUrl,
    String? title,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    DateTime? startsAt,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? clickCount,
  }) {
    return LinkGravity(
      id: id ?? this.id,
      shortCode: shortCode ?? this.shortCode,
      shortUrl: shortUrl ?? this.shortUrl,
      longUrl: longUrl ?? this.longUrl,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt ?? this.expiresAt,
      startsAt: startsAt ?? this.startsAt,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clickCount: clickCount ?? this.clickCount,
    );
  }

  @override
  String toString() {
    return 'LinkGravity(id: $id, shortCode: $shortCode, shortUrl: $shortUrl, active: $active)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LinkGravity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

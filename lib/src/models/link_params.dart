/// Configuration for deep linking behavior
class DeepLinkConfig {
  /// iOS App Store URL
  final String? iosAppStoreUrl;

  /// Android Play Store URL
  final String? androidPlayStoreUrl;

  /// Fallback URL if app is not installed
  final String? fallbackUrl;

  /// Deep link path (e.g., "/product/123")
  final String? deepLinkPath;

  /// Additional deep link parameters
  final Map<String, String>? params;

  /// Custom URL scheme (e.g., "linkgravity", "myapp")
  final String? customScheme;

  DeepLinkConfig({
    this.iosAppStoreUrl,
    this.androidPlayStoreUrl,
    this.fallbackUrl,
    this.deepLinkPath,
    this.params,
    this.customScheme,
  });

  Map<String, dynamic> toJson() {
    return {
      if (iosAppStoreUrl != null) 'iosAppStoreUrl': iosAppStoreUrl,
      if (androidPlayStoreUrl != null)
        'androidPlayStoreUrl': androidPlayStoreUrl,
      if (fallbackUrl != null) 'fallbackUrl': fallbackUrl,
      if (deepLinkPath != null) 'deepLinkPath': deepLinkPath,
      if (params != null) 'params': params,
      if (customScheme != null) 'customScheme': customScheme,
    };
  }

  factory DeepLinkConfig.fromJson(Map<String, dynamic> json) {
    return DeepLinkConfig(
      iosAppStoreUrl: json['iosAppStoreUrl'] as String?,
      androidPlayStoreUrl: json['androidPlayStoreUrl'] as String?,
      fallbackUrl: json['fallbackUrl'] as String?,
      deepLinkPath: json['deepLinkPath'] as String?,
      params: json['params'] != null
          ? Map<String, String>.from(json['params'] as Map)
          : null,
      customScheme: json['customScheme'] as String?,
    );
  }
}

/// Parameters for creating a new LinkGravity link
class LinkParams {
  /// Original long URL to be shortened
  final String longUrl;

  /// Optional custom short code (must be unique)
  final String? shortCode;

  /// Optional title/description
  final String? title;

  /// When the link becomes active
  final DateTime? startsAt;

  /// When the link expires
  final DateTime? expiresAt;

  /// Custom metadata as key-value pairs
  final Map<String, dynamic>? metadata;

  /// Deep linking configuration
  final DeepLinkConfig? deepLinkConfig;

  /// Tags for organizing links
  final List<String>? tags;

  /// Campaign identifier
  final String? campaignId;

  /// UTM parameters
  final Map<String, String>? utmParams;

  LinkParams({
    required this.longUrl,
    this.shortCode,
    this.title,
    this.startsAt,
    this.expiresAt,
    this.metadata,
    this.deepLinkConfig,
    this.tags,
    this.campaignId,
    this.utmParams,
  });

  /// Validate parameters
  bool validate() {
    if (longUrl.isEmpty) return false;

    // `hasAbsolutePath` asks whether the *path* starts with "/", which is false for a bare
    // domain — so https://example.com was rejected as invalid while https://example.com/p
    // passed. What matters is that this is an absolute http(s) URL with a host, which is
    // also what the backend accepts. The old check additionally force-unwrapped
    // `tryParse`, so genuinely malformed input threw instead of returning false.
    final uri = Uri.tryParse(longUrl);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;

    // Validate custom short code format if provided
    if (shortCode != null) {
      final shortCodeRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
      if (!shortCodeRegex.hasMatch(shortCode!)) return false;
    }

    // Validate dates
    if (startsAt != null && expiresAt != null) {
      if (startsAt!.isAfter(expiresAt!)) return false;
    }

    return true;
  }

  /// Serialise for `POST /api/v1/sdk/links`.
  ///
  /// The field names here are the backend's, not this class's: it requires `destination`
  /// and flat deep-link paths, while the public API keeps `longUrl` and a nested
  /// [DeepLinkConfig]. They disagreed on every field, so a create request that reached the
  /// route at all was rejected as invalid.
  ///
  /// `projectId` is deliberately absent — the backend resolves it from the API key, which
  /// is the only party that knows which project the key belongs to.
  ///
  /// `metadata`, `tags` and `campaignId` are not sent: no field on the backend stores
  /// them. They were being dropped silently before (Zod strips unknown keys); omitting
  /// them makes that visible rather than implying they persist.
  Map<String, dynamic> toJson() {
    final cfg = deepLinkConfig;
    final utm = utmParams;

    return {
      'destination': longUrl,
      if (shortCode != null) 'shortCode': shortCode,
      if (title != null) 'title': title,
      if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (cfg?.deepLinkPath != null) 'path': cfg!.deepLinkPath,
      if (cfg?.fallbackUrl != null) 'fallbackUrl': cfg!.fallbackUrl,
      if (utm?['source'] != null) 'source': utm!['source'],
      if (utm?['medium'] != null) 'medium': utm!['medium'],
      if (utm?['campaign'] != null) 'campaign': utm!['campaign'],
      if (utm?['term'] != null) 'term': utm!['term'],
      if (utm?['content'] != null) 'content': utm!['content'],
    };
  }

  factory LinkParams.fromJson(Map<String, dynamic> json) {
    return LinkParams(
      longUrl: json['longUrl'] as String,
      shortCode: json['shortCode'] as String?,
      title: json['title'] as String?,
      startsAt: json['startsAt'] != null
          ? DateTime.parse(json['startsAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      deepLinkConfig: json['deepLinkConfig'] != null
          ? DeepLinkConfig.fromJson(
              json['deepLinkConfig'] as Map<String, dynamic>)
          : null,
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      campaignId: json['campaignId'] as String?,
      utmParams: json['utmParams'] != null
          ? Map<String, String>.from(json['utmParams'] as Map)
          : null,
    );
  }

  @override
  String toString() {
    return 'LinkParams(longUrl: $longUrl, shortCode: $shortCode, title: $title)';
  }
}

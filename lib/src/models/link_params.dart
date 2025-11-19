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

  /// Custom URL scheme (e.g., "smartlink", "myapp")
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
      if (androidPlayStoreUrl != null) 'androidPlayStoreUrl': androidPlayStoreUrl,
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

/// Parameters for creating a new SmartLink
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
    if (!Uri.tryParse(longUrl)!.hasAbsolutePath) return false;

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

  Map<String, dynamic> toJson() {
    return {
      'longUrl': longUrl,
      if (shortCode != null) 'shortCode': shortCode,
      if (title != null) 'title': title,
      if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      if (deepLinkConfig != null) 'deepLinkConfig': deepLinkConfig!.toJson(),
      if (tags != null) 'tags': tags,
      if (campaignId != null) 'campaignId': campaignId,
      if (utmParams != null) 'utmParams': utmParams,
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
          ? DeepLinkConfig.fromJson(json['deepLinkConfig'] as Map<String, dynamic>)
          : null,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
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

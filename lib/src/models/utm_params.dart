/// UTM Parameter Model
///
/// Represents UTM (Urchin Tracking Module) parameters used for marketing attribution.
/// These parameters track the source, medium, campaign, content, and keywords
/// associated with a link or app install.
///
/// Standard UTM Parameters:
/// - `source`: Identifies which site sent the traffic (e.g., "google", "facebook")
/// - `medium`: Identifies what type of link was used (e.g., "cpc", "email", "social")
/// - `campaign`: Identifies a specific campaign (e.g., "summer_sale", "product_launch")
/// - `content`: Identifies what specifically was clicked (e.g., "banner_ad", "text_link")
/// - `term`: Identifies search terms (e.g., "running_shoes", "winter_jacket")
///
/// Example:
/// ```dart
/// final utm = UTMParams(
///   source: 'facebook',
///   medium: 'cpc',
///   campaign: 'summer_sale_2024',
///   content: 'carousel_ad',
///   term: 'running_shoes',
/// );
/// ```
class UTMParams {
  /// Traffic source (e.g., "google", "facebook", "newsletter")
  final String? source;

  /// Marketing medium (e.g., "cpc", "email", "social", "organic")
  final String? medium;

  /// Campaign identifier (e.g., "summer_sale", "product_launch")
  final String? campaign;

  /// Ad variant/content identifier (e.g., "banner_ad", "text_link")
  final String? content;

  /// Paid search keywords (e.g., "running_shoes", "winter_jacket")
  final String? term;

  const UTMParams({
    this.source,
    this.medium,
    this.campaign,
    this.content,
    this.term,
  });

  /// Create empty UTM parameters
  const UTMParams.empty()
      : source = null,
        medium = null,
        campaign = null,
        content = null,
        term = null;

  /// Extract UTM parameters from URI query string
  ///
  /// Parses standard UTM query parameters:
  /// - utm_source
  /// - utm_medium
  /// - utm_campaign
  /// - utm_content
  /// - utm_term
  ///
  /// Example:
  /// ```dart
  /// final uri = Uri.parse('https://example.com?utm_source=facebook&utm_campaign=summer');
  /// final utm = UTMParams.fromUri(uri);
  /// print(utm.source); // "facebook"
  /// print(utm.campaign); // "summer"
  /// ```
  ///
  /// Returns null if no UTM parameters are found or parsing fails.
  static UTMParams? fromUri(Uri uri) {
    try {
      final params = uri.queryParameters;
      final source = params['utm_source'];
      final medium = params['utm_medium'];
      final campaign = params['utm_campaign'];
      final content = params['utm_content'];
      final term = params['utm_term'];

      // Return null if no UTM parameters found
      if (source == null &&
          medium == null &&
          campaign == null &&
          content == null &&
          term == null) {
        return null;
      }

      return UTMParams(
        source: source,
        medium: medium,
        campaign: campaign,
        content: content,
        term: term,
      );
    } catch (e) {
      return null;
    }
  }

  /// Extract UTM parameters from URL string
  ///
  /// Convenience method that parses the URL string first.
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams.fromUrl('https://example.com?utm_source=google');
  /// ```
  static UTMParams? fromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return fromUri(uri);
    } catch (e) {
      return null;
    }
  }

  /// Extract UTM parameters from query string (without URL)
  ///
  /// Useful for Android Install Referrer strings.
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams.fromQueryString('utm_source=google&utm_campaign=summer');
  /// ```
  static UTMParams? fromQueryString(String queryString) {
    try {
      // Add dummy URL to parse query string
      final uri = Uri.parse('http://dummy?$queryString');
      return fromUri(uri);
    } catch (e) {
      return null;
    }
  }

  /// Create from JSON map
  ///
  /// Supports both camelCase and snake_case keys:
  /// - `utmSource` or `utm_source`
  /// - `utmMedium` or `utm_medium`
  /// - `utmCampaign` or `utm_campaign`
  /// - `utmContent` or `utm_content`
  /// - `utmTerm` or `utm_term`
  ///
  /// Example from API response:
  /// ```dart
  /// final json = {
  ///   'utm': {
  ///     'campaign': 'summer_sale',
  ///     'source': 'facebook',
  ///     'medium': 'cpc'
  ///   }
  /// };
  /// final utm = UTMParams.fromJson(json['utm']);
  /// ```
  factory UTMParams.fromJson(Map<String, dynamic> json) {
    return UTMParams(
      source: json['source'] ?? json['utm_source'] ?? json['utmSource'],
      medium: json['medium'] ?? json['utm_medium'] ?? json['utmMedium'],
      campaign:
          json['campaign'] ?? json['utm_campaign'] ?? json['utmCampaign'],
      content: json['content'] ?? json['utm_content'] ?? json['utmContent'],
      term: json['term'] ?? json['utm_term'] ?? json['utmTerm'],
    );
  }

  /// Convert to JSON map (camelCase keys)
  ///
  /// Used for sending to backend API.
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams(source: 'facebook', campaign: 'summer');
  /// final json = utm.toJson();
  /// // { "source": "facebook", "campaign": "summer" }
  /// ```
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (source != null) map['source'] = source;
    if (medium != null) map['medium'] = medium;
    if (campaign != null) map['campaign'] = campaign;
    if (content != null) map['content'] = content;
    if (term != null) map['term'] = term;
    return map;
  }

  /// Convert to query parameters format (utm_* keys)
  ///
  /// Used for building URLs with UTM parameters.
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams(source: 'facebook', campaign: 'summer');
  /// final params = utm.toQueryParams();
  /// // { "utm_source": "facebook", "utm_campaign": "summer" }
  /// ```
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (source != null) params['utm_source'] = source!;
    if (medium != null) params['utm_medium'] = medium!;
    if (campaign != null) params['utm_campaign'] = campaign!;
    if (content != null) params['utm_content'] = content!;
    if (term != null) params['utm_term'] = term!;
    return params;
  }

  /// Convert to flat map with utm_* keys and nullable values
  ///
  /// Used for analytics event properties.
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams(source: 'facebook');
  /// final map = utm.toMap();
  /// // {
  /// //   "utm_source": "facebook",
  /// //   "utm_medium": null,
  /// //   "utm_campaign": null,
  /// //   "utm_content": null,
  /// //   "utm_term": null
  /// // }
  /// ```
  Map<String, String?> toMap() {
    return {
      'utm_source': source,
      'utm_medium': medium,
      'utm_campaign': campaign,
      'utm_content': content,
      'utm_term': term,
    };
  }

  /// Check if all UTM parameters are null/empty
  ///
  /// Returns true if no UTM parameters are set.
  ///
  /// Example:
  /// ```dart
  /// final utm1 = UTMParams();
  /// print(utm1.isEmpty); // true
  ///
  /// final utm2 = UTMParams(source: 'facebook');
  /// print(utm2.isEmpty); // false
  /// ```
  bool get isEmpty {
    return source == null &&
        medium == null &&
        campaign == null &&
        content == null &&
        term == null;
  }

  /// Check if any UTM parameter is set
  ///
  /// Returns true if at least one UTM parameter has a value.
  bool get isNotEmpty => !isEmpty;

  /// Create a copy with modified fields
  ///
  /// Example:
  /// ```dart
  /// final utm = UTMParams(source: 'facebook', campaign: 'summer');
  /// final updated = utm.copyWith(medium: 'cpc');
  /// // source: 'facebook', campaign: 'summer', medium: 'cpc'
  /// ```
  UTMParams copyWith({
    String? source,
    String? medium,
    String? campaign,
    String? content,
    String? term,
  }) {
    return UTMParams(
      source: source ?? this.source,
      medium: medium ?? this.medium,
      campaign: campaign ?? this.campaign,
      content: content ?? this.content,
      term: term ?? this.term,
    );
  }

  /// Merge with another UTMParams
  ///
  /// Values from `other` take priority over current values.
  ///
  /// Example:
  /// ```dart
  /// final utm1 = UTMParams(source: 'facebook', campaign: 'summer');
  /// final utm2 = UTMParams(campaign: 'winter', medium: 'cpc');
  /// final merged = utm1.merge(utm2);
  /// // source: 'facebook', campaign: 'winter', medium: 'cpc'
  /// ```
  UTMParams merge(UTMParams other) {
    return UTMParams(
      source: other.source ?? source,
      medium: other.medium ?? medium,
      campaign: other.campaign ?? campaign,
      content: other.content ?? content,
      term: other.term ?? term,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (source != null) parts.add('source=$source');
    if (medium != null) parts.add('medium=$medium');
    if (campaign != null) parts.add('campaign=$campaign');
    if (content != null) parts.add('content=$content');
    if (term != null) parts.add('term=$term');

    return 'UTMParams(${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UTMParams &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          medium == other.medium &&
          campaign == other.campaign &&
          content == other.content &&
          term == other.term;

  @override
  int get hashCode => Object.hash(source, medium, campaign, content, term);
}

import 'utm_params.dart';

/// Response from deferred link lookup endpoints
///
/// This model represents the response from both:
/// - GET /api/v1/sdk/deferred-link (fingerprint matching)
/// - GET /api/v1/sdk/deferred-link/referrer/:token (Android referrer matching)
class DeferredLinkResponse {
  /// Whether the lookup was successful
  final bool success;

  /// Whether this link has already been claimed
  final bool? alreadyClaimed;

  /// When the link was claimed (if already claimed)
  final DateTime? claimedAt;

  /// Deep link data containing URL, path, and parameters
  final Map<String, dynamic>? deepLinkData;

  /// The link ID for tracking
  final String? linkId;

  /// Short code of the link
  final String? shortCode;

  /// Platform that was matched (android, ios)
  final String? platform;

  /// How the match was made: "referrer" (deterministic) or "fingerprint" (probabilistic)
  final String? matchMethod;

  /// Confidence level for fingerprint matching
  final String? confidence;

  /// Numeric score for fingerprint matching
  final int? score;

  /// Whether the link is fully resolved to a deep link destination
  /// If true, the client should not attempt to resolve the short code again.
  final bool? isResolved;

  DeferredLinkResponse({
    required this.success,
    this.alreadyClaimed,
    this.claimedAt,
    this.deepLinkData,
    this.linkId,
    this.shortCode,
    this.platform,
    this.matchMethod,
    this.confidence,
    this.score,
    this.isResolved,
  });

  /// Create from JSON (API response)
  factory DeferredLinkResponse.fromJson(Map<String, dynamic> json) {
    // Extract data from either wrapped or flat response
    final data = json.containsKey('match') && json['match'] != null
        ? json['match'] as Map<String, dynamic>
        : json;

    // Handle deepLinkData - can be nested or at match level
    Map<String, dynamic>? deepLinkData;

    if (data.containsKey('deepLinkData') && data['deepLinkData'] != null) {
      // Format 1: deepLinkData is already a nested object (Android referrer)
      deepLinkData = data['deepLinkData'] as Map<String, dynamic>;
    } else if (data.containsKey('deepLinkUrl')) {
      // Format 2: deepLinkUrl is directly in match object (iOS fingerprint)
      // Construct deepLinkData from flat structure
      deepLinkData = {
        'deepLinkUrl': data['deepLinkUrl'],
        if (data.containsKey('path')) 'path': data['path'],
        if (data.containsKey('params')) 'params': data['params'],
        if (data.containsKey('utm')) 'utm': data['utm'],
      };
    }

    return DeferredLinkResponse(
      success: json['success'] ?? true,
      alreadyClaimed: data['alreadyClaimed'] as bool?,
      claimedAt: data['claimedAt'] != null
          ? DateTime.parse(data['claimedAt'] as String)
          : null,
      deepLinkData: deepLinkData,
      linkId: data['linkId'] as String?,
      shortCode: data['shortCode'] as String?,
      platform: data['platform'] as String?,
      matchMethod: data['matchMethod'] as String?,
      confidence: data['confidence'] as String?,
      score: data['score'] as int?,
      isResolved: data['isResolved'] as bool?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'success': success,
    if (alreadyClaimed != null) 'alreadyClaimed': alreadyClaimed,
    if (claimedAt != null) 'claimedAt': claimedAt!.toIso8601String(),
    if (deepLinkData != null) 'deepLinkData': deepLinkData,
    if (linkId != null) 'linkId': linkId,
    if (shortCode != null) 'shortCode': shortCode,
    if (platform != null) 'platform': platform,
    if (matchMethod != null) 'matchMethod': matchMethod,
    if (confidence != null) 'confidence': confidence,
    if (score != null) 'score': score,
    if (isResolved != null) 'isResolved': isResolved,
  };

  /// Get deep link URL from data
  String? get deepLinkUrl => deepLinkData?['deepLinkUrl'] as String?;

  /// Get deep link path
  String? get path => deepLinkData?['path'] as String?;

  /// Get deep link parameters
  Map<String, dynamic>? get params =>
      deepLinkData?['params'] as Map<String, dynamic>?;

  /// Get UTM parameters from deep link data
  ///
  /// Returns UTM parameters that were passed through from the original
  /// short link click (e.g., utm_source=facebook&utm_campaign=summer).
  ///
  /// These UTM parameters enable complete attribution tracking from
  /// ad click → app install → conversion.
  ///
  /// Returns null if no UTM parameters were present in the original link.
  ///
  /// Example:
  /// ```dart
  /// final response = await deferredService.matchDeferredDeepLink();
  /// if (response != null && response.utm != null) {
  ///   print('Installed from: ${response.utm!.source}');
  ///   print('Campaign: ${response.utm!.campaign}');
  /// }
  /// ```
  UTMParams? get utm {
    final utmData = deepLinkData?['utm'];
    if (utmData != null && utmData is Map<String, dynamic>) {
      return UTMParams.fromJson(utmData);
    }
    return null;
  }

  /// Check if this was a deterministic match (Android referrer)
  bool get isDeterministic => matchMethod == 'referrer';

  /// Check if this was a probabilistic match (fingerprint)
  bool get isProbabilistic => matchMethod == 'fingerprint';

  /// Check if confidence level is acceptable for deferred deep linking
  bool isAcceptableConfidence() {
    if (isDeterministic) return true; // Referrer match is always reliable
    return confidence == 'high' || confidence == 'medium';
  }

  @override
  String toString() =>
      'DeferredLinkResponse('
      'success: $success, '
      'matchMethod: $matchMethod, '
      'linkId: $linkId, '
      'deepLinkUrl: $deepLinkUrl'
      ')';
}

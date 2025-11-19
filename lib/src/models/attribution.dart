/// Attribution data for user acquisition tracking
class AttributionData {
  /// Unique attribution ID
  final String id;

  /// Link ID that was clicked
  final String? linkId;

  /// Short code of the clicked link
  final String? shortCode;

  /// Campaign identifier
  final String? campaignId;

  /// UTM source
  final String? utmSource;

  /// UTM medium
  final String? utmMedium;

  /// UTM campaign
  final String? utmCampaign;

  /// UTM term
  final String? utmTerm;

  /// UTM content
  final String? utmContent;

  /// Click timestamp
  final DateTime? clickedAt;

  /// Install timestamp
  final DateTime? installedAt;

  /// First open timestamp
  final DateTime? firstOpenedAt;

  /// Deferred deep link URL (if this was a deferred link)
  final String? deferredLink;

  /// Deep link path
  final String? deepLinkPath;

  /// Deep link parameters
  final Map<String, String>? deepLinkParams;

  /// Custom attribution data
  final Map<String, dynamic>? customData;

  /// Whether this attribution is from a deferred deep link
  final bool isDeferred;

  /// Referrer URL
  final String? referrer;

  /// IP address of the click
  final String? clickIpAddress;

  /// User agent of the click
  final String? clickUserAgent;

  AttributionData({
    required this.id,
    this.linkId,
    this.shortCode,
    this.campaignId,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmTerm,
    this.utmContent,
    this.clickedAt,
    this.installedAt,
    this.firstOpenedAt,
    this.deferredLink,
    this.deepLinkPath,
    this.deepLinkParams,
    this.customData,
    this.isDeferred = false,
    this.referrer,
    this.clickIpAddress,
    this.clickUserAgent,
  });

  factory AttributionData.fromJson(Map<String, dynamic> json) {
    return AttributionData(
      id: json['id'] as String,
      linkId: json['linkId'] as String?,
      shortCode: json['shortCode'] as String?,
      campaignId: json['campaignId'] as String?,
      utmSource: json['utmSource'] as String?,
      utmMedium: json['utmMedium'] as String?,
      utmCampaign: json['utmCampaign'] as String?,
      utmTerm: json['utmTerm'] as String?,
      utmContent: json['utmContent'] as String?,
      clickedAt: json['clickedAt'] != null
          ? DateTime.parse(json['clickedAt'] as String)
          : null,
      installedAt: json['installedAt'] != null
          ? DateTime.parse(json['installedAt'] as String)
          : null,
      firstOpenedAt: json['firstOpenedAt'] != null
          ? DateTime.parse(json['firstOpenedAt'] as String)
          : null,
      deferredLink: json['deferredLink'] as String?,
      deepLinkPath: json['deepLinkPath'] as String?,
      deepLinkParams: json['deepLinkParams'] != null
          ? Map<String, String>.from(json['deepLinkParams'] as Map)
          : null,
      customData: json['customData'] as Map<String, dynamic>?,
      isDeferred: json['isDeferred'] as bool? ?? false,
      referrer: json['referrer'] as String?,
      clickIpAddress: json['clickIpAddress'] as String?,
      clickUserAgent: json['clickUserAgent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (linkId != null) 'linkId': linkId,
      if (shortCode != null) 'shortCode': shortCode,
      if (campaignId != null) 'campaignId': campaignId,
      if (utmSource != null) 'utmSource': utmSource,
      if (utmMedium != null) 'utmMedium': utmMedium,
      if (utmCampaign != null) 'utmCampaign': utmCampaign,
      if (utmTerm != null) 'utmTerm': utmTerm,
      if (utmContent != null) 'utmContent': utmContent,
      if (clickedAt != null) 'clickedAt': clickedAt!.toIso8601String(),
      if (installedAt != null) 'installedAt': installedAt!.toIso8601String(),
      if (firstOpenedAt != null) 'firstOpenedAt': firstOpenedAt!.toIso8601String(),
      if (deferredLink != null) 'deferredLink': deferredLink,
      if (deepLinkPath != null) 'deepLinkPath': deepLinkPath,
      if (deepLinkParams != null) 'deepLinkParams': deepLinkParams,
      if (customData != null) 'customData': customData,
      'isDeferred': isDeferred,
      if (referrer != null) 'referrer': referrer,
      if (clickIpAddress != null) 'clickIpAddress': clickIpAddress,
      if (clickUserAgent != null) 'clickUserAgent': clickUserAgent,
    };
  }

  @override
  String toString() {
    return 'AttributionData(id: $id, linkId: $linkId, campaignId: $campaignId, isDeferred: $isDeferred)';
  }
}

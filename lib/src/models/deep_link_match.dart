/// Deep link match result from probabilistic fingerprinting
class DeepLinkMatch {
  /// Whether a deep link was found
  final bool found;

  /// Confidence level of the match
  /// - high: Score >= 95 (very confident)
  /// - medium: 70-94 (fairly confident)
  /// - low: 50-69 (weak match)
  /// - none: < 50 (no match)
  final String confidence;

  /// Matching score (0-130)
  final int score;

  /// Deep link URL to open if match found
  final String? deepLinkUrl;

  /// Link ID for tracking
  final String? linkId;

  /// Match metadata with detailed information
  final DeepLinkMatchMetadata metadata;

  /// Web fingerprint from browser click (if available)
  final WebFingerprint? webFingerprint;

  DeepLinkMatch({
    required this.found,
    required this.confidence,
    required this.score,
    this.deepLinkUrl,
    this.linkId,
    required this.metadata,
    this.webFingerprint,
  });

  /// Check if confidence level is high enough to trust the match
  bool isHighConfidence() => confidence == 'high';

  /// Check if confidence level is acceptable for deferred deep linking
  bool isAcceptableConfidence() =>
      confidence == 'high' || confidence == 'medium';

  /// Create from JSON (API response)
  ///
  /// Handles both wrapped and flat response formats:
  /// - Wrapped: { success: true, match: { found, confidence, score, ... } }
  /// - Flat: { found, confidence, score, ... } (backward compatible)
  factory DeepLinkMatch.fromJson(Map<String, dynamic> json) {
    // Extract data from either wrapped or flat response
    final data = json.containsKey('match') && json['match'] != null
        ? json['match'] as Map<String, dynamic>
        : json;

    return DeepLinkMatch(
      found: data['found'] as bool? ?? false,
      confidence: data['confidence'] as String? ?? 'none',
      score: data['score'] as int? ?? 0,
      deepLinkUrl: data['deepLinkUrl'] as String?,
      linkId: data['linkId'] as String?,
      metadata: DeepLinkMatchMetadata.fromJson(
        data['metadata'] as Map<String, dynamic>? ?? {},
      ),
      webFingerprint: data['webFingerprint'] != null
          ? WebFingerprint.fromJson(data['webFingerprint'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'found': found,
        'confidence': confidence,
        'score': score,
        'deepLinkUrl': deepLinkUrl,
        'linkId': linkId,
        'metadata': metadata.toJson(),
        'webFingerprint': webFingerprint?.toJson(),
      };

  @override
  String toString() => 'DeepLinkMatch('
      'found: $found, '
      'confidence: $confidence, '
      'score: $score, '
      'deepLinkUrl: $deepLinkUrl, '
      'linkId: $linkId'
      ')';
}

/// Metadata for deep link match with detailed information
class DeepLinkMatchMetadata {
  /// List of attributes that matched (e.g., platform, timezone, browser)
  final List<String> matchReasons;

  /// Whether platform matched
  final bool platformMatch;

  /// Whether timezone matched
  final bool timezoneMatch;

  /// Whether locale matched
  final bool localeMatch;

  /// Whether browser family matched
  final bool browserMatch;

  /// Time window score (0-25)
  final int timeWindow;

  DeepLinkMatchMetadata({
    required this.matchReasons,
    required this.platformMatch,
    required this.timezoneMatch,
    required this.localeMatch,
    required this.browserMatch,
    required this.timeWindow,
  });

  /// Create from JSON
  factory DeepLinkMatchMetadata.fromJson(Map<String, dynamic> json) {
    return DeepLinkMatchMetadata(
      matchReasons: List<String>.from(
        json['matchReasons'] as List? ?? [],
      ),
      platformMatch: json['platformMatch'] as bool? ?? false,
      timezoneMatch: json['timezoneMatch'] as bool? ?? false,
      localeMatch: json['localeMatch'] as bool? ?? false,
      browserMatch: json['browserMatch'] as bool? ?? false,
      timeWindow: json['timeWindow'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'matchReasons': matchReasons,
        'platformMatch': platformMatch,
        'timezoneMatch': timezoneMatch,
        'localeMatch': localeMatch,
        'browserMatch': browserMatch,
        'timeWindow': timeWindow,
      };

  @override
  String toString() => 'DeepLinkMatchMetadata('
      'matchReasons: $matchReasons, '
      'platformMatch: $platformMatch, '
      'timezoneMatch: $timezoneMatch, '
      'localeMatch: $localeMatch, '
      'browserMatch: $browserMatch, '
      'timeWindow: $timeWindow'
      ')';
}

/// SDK device fingerprint for matching
class SDKFingerprint {
  /// Device platform (ios, android, web)
  final String platform;

  /// iOS Identifier for Vendor (optional, privacy-aware)
  final String? idfv;

  /// Device model (e.g., iPhone14,2, SM-G991B)
  final String model;

  /// OS version
  final String osVersion;

  /// Timezone offset in minutes
  final int timezone;

  /// Device locale (e.g., en-US, ja-JP)
  final String locale;

  /// User-Agent string
  final String userAgent;

  /// Timestamp of fingerprint collection
  final String timestamp;

  /// SDK device ID (stable identifier for install tracking)
  final String? deviceId;

  /// SDK device fingerprint hash (for install record)
  final String? deviceFingerprint;

  /// App version string
  final String? appVersion;

  SDKFingerprint({
    required this.platform,
    this.idfv,
    required this.model,
    required this.osVersion,
    required this.timezone,
    required this.locale,
    required this.userAgent,
    required this.timestamp,
    this.deviceId,
    this.deviceFingerprint,
    this.appVersion,
  });

  /// Create from JSON
  factory SDKFingerprint.fromJson(Map<String, dynamic> json) {
    return SDKFingerprint(
      platform: json['platform'] as String? ?? 'unknown',
      idfv: json['idfv'] as String?,
      model: json['model'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String? ?? 'unknown',
      timezone: json['timezone'] as int? ?? 0,
      locale: json['locale'] as String? ?? 'en-US',
      userAgent: json['userAgent'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      deviceId: json['deviceId'] as String?,
      deviceFingerprint: json['deviceFingerprint'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'platform': platform,
        if (idfv != null) 'idfv': idfv,
        'model': model,
        'osVersion': osVersion,
        'timezone': timezone,
        'locale': locale,
        'userAgent': userAgent,
        'timestamp': timestamp,
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceFingerprint != null) 'deviceFingerprint': deviceFingerprint,
        if (appVersion != null) 'appVersion': appVersion,
      };

  @override
  String toString() => 'SDKFingerprint('
      'platform: $platform, '
      'model: $model, '
      'osVersion: $osVersion, '
      'timezone: $timezone, '
      'locale: $locale'
      ')';
}

/// Web fingerprint collected from browser during link click
/// Contains detailed browser and device information for improved matching
class WebFingerprint {
  /// Real User-Agent string from browser
  final String? userAgent;

  /// Platform (e.g., "Win32", "MacIntel", "iPhone")
  final String? platform;

  /// Browser vendor (e.g., "Google Inc.", "Apple Computer, Inc.")
  final String? vendor;

  /// Browser language (e.g., "en-US")
  final String? language;

  /// List of browser languages
  final List<String>? languages;

  /// Number of CPU cores
  final int? hardwareConcurrency;

  /// Device memory in GB (if available)
  final num? deviceMemory;

  /// Maximum touch points
  final int? maxTouchPoints;

  /// Screen resolution (e.g., "1920x1080")
  final String? screenResolution;

  /// Screen color depth
  final int? screenColorDepth;

  /// Timezone (e.g., "America/Los_Angeles")
  final String? timezone;

  /// Timezone offset in minutes
  final int? timezoneOffset;

  /// Viewport size (e.g., "1280x720")
  final String? viewportSize;

  /// Canvas fingerprint hash (if available)
  final String? canvasFingerprint;

  /// WebGL vendor and renderer info
  final Map<String, dynamic>? webgl;

  /// Detected installed fonts
  final List<String>? fonts;

  /// Network connection info
  final Map<String, dynamic>? connection;

  /// Cookies enabled
  final bool? cookieEnabled;

  /// Do Not Track setting
  final String? doNotTrack;

  /// Timestamp when fingerprint was collected
  final int? timestamp;

  WebFingerprint({
    this.userAgent,
    this.platform,
    this.vendor,
    this.language,
    this.languages,
    this.hardwareConcurrency,
    this.deviceMemory,
    this.maxTouchPoints,
    this.screenResolution,
    this.screenColorDepth,
    this.timezone,
    this.timezoneOffset,
    this.viewportSize,
    this.canvasFingerprint,
    this.webgl,
    this.fonts,
    this.connection,
    this.cookieEnabled,
    this.doNotTrack,
    this.timestamp,
  });

  /// Create from JSON (from web SDK or backend)
  factory WebFingerprint.fromJson(Map<String, dynamic> json) {
    return WebFingerprint(
      userAgent: json['userAgent'] as String?,
      platform: json['platform'] as String?,
      vendor: json['vendor'] as String?,
      language: json['language'] as String?,
      languages: json['languages'] != null
          ? List<String>.from(json['languages'] as List)
          : null,
      hardwareConcurrency: json['hardwareConcurrency'] as int?,
      deviceMemory: json['deviceMemory'] as num?,
      maxTouchPoints: json['maxTouchPoints'] as int?,
      screenResolution: json['screenResolution'] as String?,
      screenColorDepth: json['screenColorDepth'] as int?,
      timezone: json['timezone'] as String?,
      timezoneOffset: json['timezoneOffset'] as int?,
      viewportSize: json['viewportSize'] as String?,
      canvasFingerprint: json['canvasFingerprint'] as String?,
      webgl: json['webgl'] != null
          ? Map<String, dynamic>.from(json['webgl'] as Map)
          : null,
      fonts: json['fonts'] != null
          ? List<String>.from(json['fonts'] as List)
          : null,
      connection: json['connection'] != null
          ? Map<String, dynamic>.from(json['connection'] as Map)
          : null,
      cookieEnabled: json['cookieEnabled'] as bool?,
      doNotTrack: json['doNotTrack'] as String?,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (userAgent != null) json['userAgent'] = userAgent;
    if (platform != null) json['platform'] = platform;
    if (vendor != null) json['vendor'] = vendor;
    if (language != null) json['language'] = language;
    if (languages != null) json['languages'] = languages;
    if (hardwareConcurrency != null) {
      json['hardwareConcurrency'] = hardwareConcurrency;
    }
    if (deviceMemory != null) json['deviceMemory'] = deviceMemory;
    if (maxTouchPoints != null) json['maxTouchPoints'] = maxTouchPoints;
    if (screenResolution != null) json['screenResolution'] = screenResolution;
    if (screenColorDepth != null) json['screenColorDepth'] = screenColorDepth;
    if (timezone != null) json['timezone'] = timezone;
    if (timezoneOffset != null) json['timezoneOffset'] = timezoneOffset;
    if (viewportSize != null) json['viewportSize'] = viewportSize;
    if (canvasFingerprint != null) {
      json['canvasFingerprint'] = canvasFingerprint;
    }
    if (webgl != null) json['webgl'] = webgl;
    if (fonts != null) json['fonts'] = fonts;
    if (connection != null) json['connection'] = connection;
    if (cookieEnabled != null) json['cookieEnabled'] = cookieEnabled;
    if (doNotTrack != null) json['doNotTrack'] = doNotTrack;
    if (timestamp != null) json['timestamp'] = timestamp;

    return json;
  }

  @override
  String toString() => 'WebFingerprint('
      'userAgent: $userAgent, '
      'platform: $platform, '
      'timezone: $timezone, '
      'screenResolution: $screenResolution'
      ')';
}

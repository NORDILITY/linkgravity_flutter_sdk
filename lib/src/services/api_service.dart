import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/link.dart';
import '../models/link_params.dart';
import '../models/attribution.dart';
import '../models/analytics_event.dart';
import '../utils/logger.dart';

/// Exception thrown when API request fails
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  ApiException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Service for communicating with LinkGravity Backend API
class ApiService {
  /// Base URL of the LinkGravity backend (e.g., "https://api.linkgravity.io")
  final String baseUrl;

  /// API Key for authentication
  final String? apiKey;

  /// HTTP client (can be mocked for testing)
  final http.Client client;

  /// Default request timeout
  final Duration timeout;

  ApiService({
    required this.baseUrl,
    this.apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : client = client ?? http.Client();

  /// Get default headers for API requests
  Map<String, String> get headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (apiKey != null) {
      headers['Authorization'] = 'Bearer ${apiKey!}';
    }

    return headers;
  }

  /// Build full URL from path
  String _buildUrl(String path) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  /// Make GET request
  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse(_buildUrl(path));

      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      LinkGravityLogger.debug('GET $uri');

      final response =
          await client.get(uri, headers: headers).timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      LinkGravityLogger.error('GET request failed: $path', e);
      rethrow;
    }
  }

  /// Make POST request
  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      LinkGravityLogger.debug('POST $uri');
      LinkGravityLogger.verbose('Request body: $body');

      final response = await client
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      LinkGravityLogger.error('POST request failed: $path', e);
      rethrow;
    }
  }

  /// Make PUT request
  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      LinkGravityLogger.debug('PUT $uri');

      final response = await client
          .put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      LinkGravityLogger.error('PUT request failed: $path', e);
      rethrow;
    }
  }

  /// Make DELETE request
  Future<void> _delete(String path) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      LinkGravityLogger.debug('DELETE $uri');

      final response =
          await client.delete(uri, headers: headers).timeout(timeout);

      _handleResponse(response);
    } catch (e) {
      LinkGravityLogger.error('DELETE request failed: $path', e);
      rethrow;
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    LinkGravityLogger.debug('Response status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        LinkGravityLogger.error('Failed to parse response body', e);
        throw ApiException('Invalid JSON response');
      }
    } else {
      // Error response
      String errorMessage = 'Request failed with status ${response.statusCode}';

      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = errorBody['message'] ?? errorMessage;
      } catch (_) {
        // If we can't parse error body, use default message
      }

      throw ApiException(
        errorMessage,
        statusCode: response.statusCode,
        response: response.body,
      );
    }
  }

  // ============================================================================
  // LINK MANAGEMENT
  // ============================================================================

  /// Create a new LinkGravity
  /// POST /api/v1/links
  Future<LinkGravity> createLink(LinkParams params) async {
    if (!params.validate()) {
      throw ApiException('Invalid link parameters');
    }

    final response = await _post('/api/v1/links', params.toJson());

    if (response['success'] == true && response['data'] != null) {
      return LinkGravity.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw ApiException('Failed to create link: ${response['message']}');
  }

  /// Get a specific link by ID
  /// GET /api/v1/links/:id
  Future<LinkGravity> getLink(String linkId) async {
    final response = await _get('/api/v1/links/$linkId');

    if (response['success'] == true && response['data'] != null) {
      return LinkGravity.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw ApiException('Failed to get link: ${response['message']}');
  }

  /// Get all links (with pagination)
  /// GET /api/v1/links
  Future<List<LinkGravity>> getLinks({
    int? limit,
    int? offset,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (search != null) queryParams['search'] = search;

    final response = await _get('/api/v1/links', queryParams: queryParams);

    if (response['success'] == true && response['data'] != null) {
      final linksData = response['data'] as List;
      return linksData
          .map((json) => LinkGravity.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw ApiException('Failed to get links: ${response['message']}');
  }

  /// Update an existing link
  /// PUT /api/v1/links/:id
  Future<LinkGravity> updateLink(String linkId, LinkParams params) async {
    final response = await _put('/api/v1/links/$linkId', params.toJson());

    if (response['success'] == true && response['data'] != null) {
      return LinkGravity.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw ApiException('Failed to update link: ${response['message']}');
  }

  /// Delete a link
  /// DELETE /api/v1/links/:id
  Future<void> deleteLink(String linkId) async {
    await _delete('/api/v1/links/$linkId');
  }

  // ============================================================================
  // SDK / DEFERRED DEEP LINKING
  // ============================================================================

  /// Get deferred deep link by Android Play Install Referrer token
  /// GET /api/v1/sdk/deferred-link/referrer/:token
  ///
  /// LINK-004: Deterministic matching for Android using Play Install Referrer API.
  /// This provides 100% accurate attribution for Android installs.
  ///
  /// Returns [DeferredLinkResponse] if a match is found, null otherwise.
  Future<Map<String, dynamic>?> getDeferredLinkByReferrer(
      String referrerToken) async {
    try {
      LinkGravityLogger.debug(
          'Looking up deferred link by referrer token: ${referrerToken.substring(0, referrerToken.length > 20 ? 20 : referrerToken.length)}...');

      final response =
          await _get('/api/v1/sdk/deferred-link/referrer/$referrerToken');

      if (response['success'] == true) {
        LinkGravityLogger.info('Deferred link found via referrer token');
        return response;
      }

      LinkGravityLogger.debug('No deferred link found for referrer token');
      return null;
    } catch (e) {
      LinkGravityLogger.warning('No deferred link found for referrer token', e);
      return null;
    }
  }

  /// Get deferred deep link data (after app install) using fingerprint
  /// GET /api/v1/sdk/deferred-link?fingerprint=...
  ///
  /// This is the probabilistic fallback method when Android referrer is not available.
  Future<AttributionData?> getDeferredLink(String fingerprint) async {
    try {
      final response = await _get(
        '/api/v1/sdk/deferred-link',
        queryParams: {'fingerprint': fingerprint},
      );

      if (response['success'] == true && response['data'] != null) {
        return AttributionData.fromJson(
            response['data'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      LinkGravityLogger.warning('No deferred link found', e);
      return null;
    }
  }

  /// Track app install
  /// POST /api/v1/sdk/install
  ///
  /// Tracks app installation with device information and optional deferred link attribution.
  ///
  /// Parameters:
  /// - [fingerprint]: Device fingerprint for attribution
  /// - [deviceId]: Unique device identifier
  /// - [platform]: Platform name (android, ios)
  /// - [appVersion]: App version string
  /// - [deferredLinkId]: ID of matched deferred link (if any)
  /// - [matchMethod]: How the deferred link was matched ('referrer' or 'fingerprint')
  /// - [matchConfidence]: Confidence level of the match
  /// - [matchScore]: Numeric score of the match
  Future<bool> trackInstall({
    String? fingerprint,
    String? deviceId,
    String? platform,
    String? appVersion,
    String? deferredLinkId,
    String? matchMethod,
    String? matchConfidence,
    double? matchScore,
  }) async {
    try {
      await _post('/api/v1/sdk/install', {
        'timestamp': DateTime.now().toIso8601String(),
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (deviceId != null) 'deviceId': deviceId,
        if (platform != null) 'platform': platform,
        if (appVersion != null) 'appVersion': appVersion,
        if (deferredLinkId != null) 'deferredLinkId': deferredLinkId,
        if (matchMethod != null) 'matchMethod': matchMethod,
        if (matchConfidence != null) 'matchConfidence': matchConfidence,
        if (matchScore != null) 'matchScore': matchScore,
      });

      LinkGravityLogger.info('Installation tracked successfully');
      return true;
    } catch (e) {
      LinkGravityLogger.error('Error tracking installation: $e', e);
      return false;
    }
  }

  /// Track SDK event
  /// POST /api/v1/sdk/events
  Future<void> trackSdkEvent({
    required String name,
    Map<String, dynamic>? properties,
    String? linkId,
    String? fingerprint,
    String? deviceId,
  }) async {
    await _post('/api/v1/sdk/events', {
      'name': name,
      if (properties != null) 'properties': properties,
      if (linkId != null) 'linkId': linkId,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (deviceId != null) 'deviceId': deviceId,
    });
  }

  /// Track conversion (purchase, signup, etc.)
  /// POST /api/v1/sdk/conversions
  ///
  /// Tracks conversion events like purchases, signups, or other valuable actions.
  ///
  /// Parameters:
  /// - [type]: Type of conversion (e.g., 'purchase', 'signup', 'subscription')
  /// - [revenue]: Revenue amount (optional)
  /// - [currency]: Currency code (default: 'USD')
  /// - [linkId]: Associated link ID for attribution
  /// - [eventId]: Unique event identifier
  /// - [metadata]: Additional conversion data
  Future<bool> trackConversion({
    required String type,
    double? revenue,
    String currency = 'USD',
    String? linkId,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _post('/api/v1/sdk/conversions', {
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        if (revenue != null) 'revenue': revenue,
        'currency': currency,
        if (linkId != null) 'linkId': linkId,
        if (eventId != null) 'eventId': eventId,
        if (metadata != null) 'metadata': metadata,
      });

      LinkGravityLogger.info(
          'Conversion tracked: $type${linkId != null ? ' for $linkId' : ''}');
      return true;
    } catch (e) {
      LinkGravityLogger.error('Error tracking conversion: $e', e);
      return false;
    }
  }

  /// Get SDK configuration
  /// GET /api/v1/sdk/config
  ///
  /// Returns SDK configuration from backend including:
  /// - version: Config version number
  /// - deferredLinkTimeout: Timeout for deferred link matching in ms
  /// - enableAnalytics: Whether analytics is enabled
  Future<Map<String, dynamic>> getSdkConfig() async {
    final response = await _get('/api/v1/sdk/config');

    if (response['success'] == true && response['config'] != null) {
      return response['config'] as Map<String, dynamic>;
    }

    return {};
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Send batch of analytics events
  /// POST /api/v1/events (bulk)
  ///
  /// Backend expects: { events: [{ type, properties, timestamp, sessionId }], fingerprint?, deviceId?, sessionId? }
  /// SDK sends: { events: [{ id, name, data, timestamp, ... }] }
  /// This method transforms the SDK format to match the backend schema.
  Future<void> sendBatch(List<AnalyticsEvent> events) async {
    if (events.isEmpty) return;

    // Transform events to match backend schema
    // Backend uses 'type' instead of 'name' and 'properties' instead of 'data'
    final eventsJson = events.map((e) => {
      'type': e.name,
      'properties': e.data,
      'timestamp': e.timestamp.toIso8601String(),
      if (e.sessionId != null) 'sessionId': e.sessionId,
    }).toList();

    // Extract common fields from first event (all events in batch share same fingerprint/session)
    final firstEvent = events.first;

    await _post('/api/v1/events', {
      'events': eventsJson,
      if (firstEvent.fingerprint != null) 'fingerprint': firstEvent.fingerprint,
      if (firstEvent.sessionId != null) 'sessionId': firstEvent.sessionId,
    });

    LinkGravityLogger.info('Sent ${events.length} events to backend');
  }

  /// Track single event
  /// POST /api/v1/events
  Future<void> trackEvent(AnalyticsEvent event) async {
    await _post('/api/v1/events', event.toJson());
  }

  // ============================================================================
  // CLICK TRACKING
  // ============================================================================

  /// Track link click
  /// This is typically handled by the backend redirect, but can be called manually
  Future<void> trackClick(String linkId, Map<String, dynamic> data) async {
    await _post('/api/v1/links/$linkId/click', data);
  }

  // ============================================================================
  // DEFERRED DEEP LINKING
  // ============================================================================

  /// Match deferred deep link with device fingerprint
  /// POST /api/v1/sdk/match
  /// Public endpoint (no authentication required)
  Future<Map<String, dynamic>?> matchLink(dynamic fingerprint) async {
    try {
      LinkGravityLogger.debug('Matching deferred deep link with fingerprint');

      final response = await _post(
        '/api/v1/sdk/match',
        fingerprint is Map ? fingerprint : fingerprint.toJson(),
      );

      if (response['success'] != true) {
        LinkGravityLogger.debug('No match found for deferred deep link');
        return null;
      }

      LinkGravityLogger.info('Deferred deep link match found');
      return response;
    } catch (e) {
      LinkGravityLogger.warning('Error matching deferred deep link: $e');
      return null;
    }
  }

  /// Resolve shortCode to target route
  /// GET /api/v1/sdk/resolve/:shortCode
  ///
  /// Used when Android/iOS intercepts App Link and SDK needs to know where to navigate.
  /// This is the Branch.io pattern - when the app is already installed, App Links
  /// intercept ALL paths from the configured domain, so we need to ask the backend
  /// what route the shortCode should map to.
  ///
  /// Parameters:
  /// - [shortCode]: The short code to resolve (e.g., 'tappick-test')
  /// - [platform]: Platform name ('android' or 'ios')
  ///
  /// Returns a map with:
  /// - success: true/false
  /// - route: The target route (e.g., '/hidden?ref=Test13')
  /// - destination: The original long URL
  /// - utm: UTM parameters object
  ///
  /// Example:
  /// ```dart
  /// final result = await api.resolveShortCode('tappick-test', 'android');
  /// if (result != null && result['success'] == true) {
  ///   final route = result['route']; // '/hidden?ref=Test13'
  ///   // Navigate to route
  /// }
  /// ```
  Future<Map<String, dynamic>?> resolveShortCode(
    String shortCode, {
    String platform = 'android',
  }) async {
    try {
      LinkGravityLogger.debug('Resolving shortCode: $shortCode (platform: $platform)');

      final response = await _get(
        '/api/v1/sdk/resolve/$shortCode',
        queryParams: {'platform': platform},
      );

      if (response['success'] == true) {
        LinkGravityLogger.info('ShortCode resolved: $shortCode → ${response['route']}');
        return response;
      }

      LinkGravityLogger.warning('Failed to resolve shortCode: $shortCode');
      return null;
    } catch (e) {
      LinkGravityLogger.warning('Error resolving shortCode: $shortCode', e);
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    client.close();
  }
}

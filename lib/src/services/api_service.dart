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

/// Service for communicating with SmartLink Backend API
class ApiService {
  /// Base URL of the SmartLink backend (e.g., "https://api.smartlink.io")
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
    this.timeout = const Duration(seconds: 30),
  }) : client = client ?? http.Client();

  /// Get default headers for API requests
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }

    return headers;
  }

  /// Build full URL from path
  String _buildUrl(String path) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  /// Make GET request
  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse(_buildUrl(path));

      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      SmartLinkLogger.debug('GET $uri');

      final response = await client.get(uri, headers: _headers).timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      SmartLinkLogger.error('GET request failed: $path', e);
      rethrow;
    }
  }

  /// Make POST request
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      SmartLinkLogger.debug('POST $uri');
      SmartLinkLogger.verbose('Request body: $body');

      final response = await client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      SmartLinkLogger.error('POST request failed: $path', e);
      rethrow;
    }
  }

  /// Make PUT request
  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      SmartLinkLogger.debug('PUT $uri');

      final response = await client
          .put(
            uri,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      SmartLinkLogger.error('PUT request failed: $path', e);
      rethrow;
    }
  }

  /// Make DELETE request
  Future<void> _delete(String path) async {
    try {
      final uri = Uri.parse(_buildUrl(path));

      SmartLinkLogger.debug('DELETE $uri');

      final response = await client.delete(uri, headers: _headers).timeout(timeout);

      _handleResponse(response);
    } catch (e) {
      SmartLinkLogger.error('DELETE request failed: $path', e);
      rethrow;
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    SmartLinkLogger.debug('Response status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        SmartLinkLogger.error('Failed to parse response body', e);
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

  /// Create a new SmartLink
  /// POST /api/v1/links
  Future<SmartLink> createLink(LinkParams params) async {
    if (!params.validate()) {
      throw ApiException('Invalid link parameters');
    }

    final response = await _post('/api/v1/links', params.toJson());

    if (response['success'] == true && response['data'] != null) {
      return SmartLink.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw ApiException('Failed to create link: ${response['message']}');
  }

  /// Get a specific link by ID
  /// GET /api/v1/links/:id
  Future<SmartLink> getLink(String linkId) async {
    final response = await _get('/api/v1/links/$linkId');

    if (response['success'] == true && response['data'] != null) {
      return SmartLink.fromJson(response['data'] as Map<String, dynamic>);
    }

    throw ApiException('Failed to get link: ${response['message']}');
  }

  /// Get all links (with pagination)
  /// GET /api/v1/links
  Future<List<SmartLink>> getLinks({
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
      return linksData.map((json) => SmartLink.fromJson(json as Map<String, dynamic>)).toList();
    }

    throw ApiException('Failed to get links: ${response['message']}');
  }

  /// Update an existing link
  /// PUT /api/v1/links/:id
  Future<SmartLink> updateLink(String linkId, LinkParams params) async {
    final response = await _put('/api/v1/links/$linkId', params.toJson());

    if (response['success'] == true && response['data'] != null) {
      return SmartLink.fromJson(response['data'] as Map<String, dynamic>);
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

  /// Get deferred deep link data (after app install)
  /// GET /api/v1/sdk/deferred-link?fingerprint=...
  Future<AttributionData?> getDeferredLink(String fingerprint) async {
    try {
      final response = await _get(
        '/api/v1/sdk/deferred-link',
        queryParams: {'fingerprint': fingerprint},
      );

      if (response['success'] == true && response['data'] != null) {
        return AttributionData.fromJson(response['data'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      SmartLinkLogger.warning('No deferred link found', e);
      return null;
    }
  }

  /// Track app install
  /// POST /api/v1/sdk/install
  Future<void> trackInstall({
    required String fingerprint,
    required String deviceId,
    required String platform,
    String? appVersion,
  }) async {
    await _post('/api/v1/sdk/install', {
      'fingerprint': fingerprint,
      'deviceId': deviceId,
      'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
    });
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
  Future<void> trackConversion({
    required String type,
    required double revenue,
    String currency = 'USD',
    String? linkId,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) async {
    await _post('/api/v1/sdk/conversions', {
      'type': type,
      'revenue': revenue,
      'currency': currency,
      if (linkId != null) 'linkId': linkId,
      if (eventId != null) 'eventId': eventId,
      if (metadata != null) 'metadata': metadata,
    });
  }

  /// Get SDK configuration
  /// GET /api/v1/sdk/config
  Future<Map<String, dynamic>> getSdkConfig() async {
    final response = await _get('/api/v1/sdk/config');

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }

    return {};
  }

  // ============================================================================
  // ANALYTICS
  // ============================================================================

  /// Send batch of analytics events
  /// POST /api/v1/events (bulk)
  Future<void> sendBatch(List<AnalyticsEvent> events) async {
    if (events.isEmpty) return;

    final eventsJson = events.map((e) => e.toJson()).toList();

    await _post('/api/v1/events', {
      'events': eventsJson,
    });

    SmartLinkLogger.info('Sent ${events.length} events to backend');
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

  /// Dispose resources
  void dispose() {
    client.close();
  }
}

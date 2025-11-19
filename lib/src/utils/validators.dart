/// Input validation utilities for SmartLink SDK
class Validators {
  /// Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Must have a scheme (http, https, etc.)
    if (uri.scheme.isEmpty) return false;

    // Must have a host
    if (uri.host.isEmpty) return false;

    return true;
  }

  /// Validate HTTP/HTTPS URL
  static bool isValidHttpUrl(String url) {
    if (!isValidUrl(url)) return false;

    final uri = Uri.parse(url);
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Validate short code format
  /// Short codes must be 3-20 characters, alphanumeric, underscore, or hyphen
  static bool isValidShortCode(String shortCode) {
    if (shortCode.isEmpty) return false;

    final regex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
    return regex.hasMatch(shortCode);
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  /// Validate UUID format
  static bool isValidUuid(String uuid) {
    if (uuid.isEmpty) return false;

    final regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return regex.hasMatch(uuid);
  }

  /// Validate date range
  static bool isValidDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return true;
    return start.isBefore(end);
  }

  /// Validate metadata size (max 10KB)
  static bool isValidMetadataSize(Map<String, dynamic>? metadata) {
    if (metadata == null) return true;

    // Rough estimate of JSON size
    final jsonString = metadata.toString();
    final sizeInBytes = jsonString.length;

    // Max 10KB
    return sizeInBytes <= 10 * 1024;
  }

  /// Sanitize user input (remove potentially harmful characters)
  static String sanitizeInput(String input) {
    // Remove control characters and trim
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  /// Validate deep link path format
  static bool isValidDeepLinkPath(String path) {
    if (path.isEmpty) return false;

    // Must start with /
    if (!path.startsWith('/')) return false;

    // No double slashes
    if (path.contains('//')) return false;

    // Only alphanumeric, slash, hyphen, underscore
    final regex = RegExp(r'^[a-zA-Z0-9/_-]+$');
    return regex.hasMatch(path);
  }

  /// Validate campaign ID format
  static bool isValidCampaignId(String campaignId) {
    if (campaignId.isEmpty) return false;

    // Alphanumeric, underscore, hyphen (1-50 chars)
    final regex = RegExp(r'^[a-zA-Z0-9_-]{1,50}$');
    return regex.hasMatch(campaignId);
  }
}

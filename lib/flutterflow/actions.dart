/// FlutterFlow Custom Actions for LinkGravity SDK
///
/// These functions are optimized for use in FlutterFlow's Custom Action system.
/// They provide simple, stateless functions that can be called from FlutterFlow UI.
///
/// ## Setup in FlutterFlow
///
/// 1. Add this package to your FlutterFlow project dependencies
/// 2. Import these custom actions
/// 3. Call `initLinkGravity()` in your App State > On App Start
/// 4. Use other actions throughout your app
library linkgravity_flutterflow;

import 'dart:convert';
import '../linkgravity_flutter_sdk.dart';

/// Initialize LinkGravity SDK
///
/// Use in: App State > On App Start
///
/// Parameters:
/// - [baseUrl]: Your LinkGravity backend URL (e.g., "https://localhost:3000")
/// - [apiKey]: Your LinkGravity API key (optional)
/// - [enableAnalytics]: Enable analytics tracking (default: true)
/// - [enableDeepLinking]: Enable deep linking (default: true)
///
/// Returns: `true` if successful, `false` otherwise
Future<bool> initLinkGravity({
  required String baseUrl,
  String? apiKey,
  bool enableAnalytics = true,
  bool enableDeepLinking = true,
}) async {
  try {
    await LinkGravityClient.initialize(
      baseUrl: baseUrl,
      apiKey: apiKey,
      config: LinkGravityConfig(
        enableAnalytics: enableAnalytics,
        enableDeepLinking: enableDeepLinking,
        logLevel: LogLevel.info,
      ),
    );
    return true;
  } catch (e) {
    print('Failed to initialize LinkGravity: $e');
    return false;
  }
}

/// Create a LinkGravity
///
/// Parameters:
/// - [longUrl]: The original URL to shorten (required)
/// - [title]: Optional title for the link
/// - [shortCode]: Optional custom short code
/// - [deepLinkPath]: Optional deep link path (e.g., "/product/123")
/// - [iosAppStoreUrl]: Optional iOS App Store URL
/// - [androidPlayStoreUrl]: Optional Android Play Store URL
///
/// Returns: Short URL as String, or null if failed
Future<String?> createLinkGravity({
  required String longUrl,
  String? title,
  String? shortCode,
  String? deepLinkPath,
  String? iosAppStoreUrl,
  String? androidPlayStoreUrl,
}) async {
  try {
    final link = await LinkGravityClient.instance.createLink(
      LinkParams(
        longUrl: longUrl,
        title: title,
        shortCode: shortCode,
        deepLinkConfig: DeepLinkConfig(
          deepLinkPath: deepLinkPath,
          iosAppStoreUrl: iosAppStoreUrl,
          androidPlayStoreUrl: androidPlayStoreUrl,
        ),
      ),
    );
    return link.shortUrl;
  } catch (e) {
    print('Failed to create LinkGravity: $e');
    return null;
  }
}

/// Track a custom event
///
/// Parameters:
/// - [eventName]: Name of the event (required)
/// - [propertyKey1]: Optional property key (for simple key-value tracking)
/// - [propertyValue1]: Optional property value
/// - [propertyKey2]: Optional second property key
/// - [propertyValue2]: Optional second property value
///
/// For more complex properties, use [trackLinkGravityEventWithJSON]
Future<void> trackLinkGravityEvent({
  required String eventName,
  String? propertyKey1,
  String? propertyValue1,
  String? propertyKey2,
  String? propertyValue2,
}) async {
  try {
    final properties = <String, dynamic>{};

    if (propertyKey1 != null && propertyValue1 != null) {
      properties[propertyKey1] = propertyValue1;
    }

    if (propertyKey2 != null && propertyValue2 != null) {
      properties[propertyKey2] = propertyValue2;
    }

    await LinkGravityClient.instance.trackEvent(
      eventName,
      properties.isNotEmpty ? properties : null,
    );
  } catch (e) {
    print('Failed to track event: $e');
  }
}

/// Track a custom event with JSON properties
///
/// Parameters:
/// - [eventName]: Name of the event (required)
/// - [propertiesJson]: JSON string of event properties
///
/// Example JSON:
/// ```json
/// {
///   "productId": "123",
///   "price": 29.99,
///   "category": "electronics"
/// }
/// ```
Future<void> trackLinkGravityEventWithJSON({
  required String eventName,
  required String propertiesJson,
}) async {
  try {
    final properties = jsonDecode(propertiesJson) as Map<String, dynamic>;

    await LinkGravityClient.instance.trackEvent(eventName, properties);
  } catch (e) {
    print('Failed to track event: $e');
  }
}

/// Track a conversion (purchase, signup, etc.)
///
/// Parameters:
/// - [type]: Conversion type (e.g., "purchase", "signup")
/// - [revenue]: Revenue amount
/// - [currency]: Currency code (default: "USD")
/// - [linkId]: Optional link ID to attribute to
///
/// Returns: `true` if successful, `false` otherwise
Future<bool> trackLinkGravityConversion({
  required String type,
  required double revenue,
  String currency = 'USD',
  String? linkId,
}) async {
  try {
    await LinkGravityClient.instance.trackConversion(
      type: type,
      revenue: revenue,
      currency: currency,
      linkId: linkId,
    );
    return true;
  } catch (e) {
    print('Failed to track conversion: $e');
    return false;
  }
}

/// Get attribution data as JSON string
///
/// Returns: JSON string of attribution data, or null if no attribution found
///
/// Example returned JSON:
/// ```json
/// {
///   "id": "...",
///   "linkId": "...",
///   "campaignId": "summer_sale",
///   "utmSource": "facebook",
///   "isDeferred": true
/// }
/// ```
Future<String?> getLinkGravityAttribution() async {
  try {
    final attribution = await LinkGravityClient.instance.getAttribution();

    if (attribution != null) {
      return jsonEncode(attribution.toJson());
    }

    return null;
  } catch (e) {
    print('Failed to get attribution: $e');
    return null;
  }
}

/// Set user ID for attribution tracking
///
/// Call this after user logs in.
///
/// Parameters:
/// - [userId]: User ID to set
Future<void> setLinkGravityUserId({required String userId}) async {
  try {
    await LinkGravityClient.instance.setUserId(userId);
  } catch (e) {
    print('Failed to set user ID: $e');
  }
}

/// Clear user ID (e.g., on logout)
Future<void> clearLinkGravityUserId() async {
  try {
    await LinkGravityClient.instance.clearUserId();
  } catch (e) {
    print('Failed to clear user ID: $e');
  }
}

/// Get device fingerprint
///
/// Returns: Device fingerprint string, or null if SDK not initialized
Future<String?> getLinkGravityFingerprint() async {
  try {
    return LinkGravityClient.instance.fingerprint;
  } catch (e) {
    print('Failed to get fingerprint: $e');
    return null;
  }
}

/// Get session ID
///
/// Returns: Current session ID, or null if SDK not initialized
Future<String?> getLinkGravitySessionId() async {
  try {
    return LinkGravityClient.instance.sessionId;
  } catch (e) {
    print('Failed to get session ID: $e');
    return null;
  }
}

/// Manually flush pending analytics events
///
/// Useful before app goes to background or user logs out.
///
/// Returns: `true` if successful, `false` otherwise
Future<bool> flushLinkGravityEvents() async {
  try {
    await LinkGravityClient.instance.flushEvents();
    return true;
  } catch (e) {
    print('Failed to flush events: $e');
    return false;
  }
}

/// Get the initial deep link string (if app was opened via deep link)
///
/// Returns: the raw link (e.g. `https://example.com/abc123` or `myapp://foo`),
/// or null if no initial deep link is present.
Future<String?> getInitialDeepLink() async {
  try {
    return LinkGravityClient.instance.initialDeepLink;
  } catch (e) {
    print('Failed to get initial deep link: $e');
    return null;
  }
}

/// Check if SDK is initialized
///
/// Returns: `true` if initialized, `false` otherwise
Future<bool> isLinkGravityInitialized() async {
  try {
    return LinkGravityClient.instance.isInitialized;
  } catch (e) {
    return false;
  }
}

/// Reset LinkGravity SDK (clear all data)
///
/// WARNING: This will clear all cached data including attribution!
///
/// Returns: `true` if successful, `false` otherwise
Future<bool> resetLinkGravity() async {
  try {
    await LinkGravityClient.instance.reset();
    return true;
  } catch (e) {
    print('Failed to reset LinkGravity: $e');
    return false;
  }
}

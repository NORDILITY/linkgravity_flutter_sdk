import 'dart:io';

import 'package:flutter/services.dart';

import '../models/utm_params.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

/// Service for handling Android Play Install Referrer API (Native Implementation)
///
/// This service retrieves the install referrer from Play Store via native
/// Android code (Method Channel), which contains the deferred deep link token
/// for deterministic matching.
///
/// The Play Install Referrer API provides 100% accurate attribution for
/// Android installs that originate from SmartLinks.
///
/// Usage:
/// ```dart
/// final service = InstallReferrerService();
/// final token = await service.getInstallReferrer();
/// if (token != null) {
///   // Use token for deterministic deferred deep linking
/// }
/// ```
class InstallReferrerService {
  static const _channel = MethodChannel('smartlink_flutter_sdk');
  static const String _keyInstallUTM = 'smartlink_install_utm';

  static bool _checked = false;
  static String? _referrerToken;
  static String? _rawReferrer;
  static int? _installTimestamp;
  static int? _clickTimestamp;
  static UTMParams? _cachedUTM;

  final StorageService _storage;

  /// Create Install Referrer Service
  InstallReferrerService(this._storage);

  /// Check if we're on Android
  bool get isAndroid => Platform.isAndroid;

  /// Check if referrer has already been retrieved
  bool get hasCheckedReferrer => _checked;

  /// Get cached referrer token (if available)
  String? get cachedReferrerToken => _referrerToken;

  /// Get the raw referrer string (for debugging)
  String? get rawReferrer => _rawReferrer;

  /// Get the install timestamp (seconds since epoch)
  int? get installTimestamp => _installTimestamp;

  /// Get the click timestamp (seconds since epoch)
  int? get clickTimestamp => _clickTimestamp;

  /// Retrieve install referrer from Play Store
  ///
  /// Returns the `deferred_link` token if present in the referrer URL.
  /// This token can be used for deterministic deferred deep linking.
  ///
  /// Returns null if:
  /// - Not on Android
  /// - Referrer API not available
  /// - No deferred_link parameter in referrer
  /// - App was not installed from Play Store
  Future<String?> getInstallReferrer() async {
    if (!isAndroid) {
      SmartLinkLogger.debug('Not Android, skipping Install Referrer');
      return null;
    }

    if (_checked && _referrerToken != null) {
      SmartLinkLogger.debug('Returning cached referrer token');
      return _referrerToken;
    }

    try {
      SmartLinkLogger.info('Retrieving Play Install Referrer (native)...');

      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getInstallReferrer');

      if (result == null) {
        SmartLinkLogger.debug('No result from native install referrer');
        _checked = true;
        return null;
      }

      // Check for error response
      if (result['error'] == true) {
        final errorCode = result['errorCode'] as int?;
        final message = result['message'] as String?;
        SmartLinkLogger.warning(
            'Install referrer error: $message (code: $errorCode)');
        _checked = true;
        return null;
      }

      // Extract successful response
      final referrerUrl = result['referrer'] as String?;
      _rawReferrer = referrerUrl;
      _installTimestamp = (result['installTimestamp'] as num?)?.toInt();
      _clickTimestamp = (result['clickTimestamp'] as num?)?.toInt();

      SmartLinkLogger.debug('Raw referrer URL: $referrerUrl');
      if (_installTimestamp != null && _installTimestamp! > 0) {
        SmartLinkLogger.debug('Install timestamp: $_installTimestamp');
      }
      if (_clickTimestamp != null && _clickTimestamp! > 0) {
        SmartLinkLogger.debug('Click timestamp: $_clickTimestamp');
      }

      if (referrerUrl == null || referrerUrl.isEmpty) {
        SmartLinkLogger.debug('Empty referrer URL');
        _checked = true;
        return null;
      }

      // Parse referrer URL to extract deferred_link token
      // Format: utm_source=smartlink&utm_campaign=ABC123&deferred_link=<token>
      _referrerToken = _extractDeferredLinkToken(referrerUrl);

      if (_referrerToken != null) {
        SmartLinkLogger.info(
            'Found deferred_link token: ${_referrerToken!.substring(0, _referrerToken!.length > 20 ? 20 : _referrerToken!.length)}...');
      } else {
        SmartLinkLogger.debug('No deferred_link parameter in referrer');
      }

      _checked = true;

      // Cache UTM parameters from referrer
      await _cacheUTMParams();

      return _referrerToken;
    } on PlatformException catch (e) {
      SmartLinkLogger.error('Platform error retrieving install referrer', e);
      _checked = true;
      return null;
    } catch (e, stackTrace) {
      SmartLinkLogger.error('Error retrieving install referrer', e, stackTrace);
      _checked = true;
      return null;
    }
  }

  /// Extract the deferred_link token from the referrer URL
  ///
  /// The referrer URL format is typically:
  /// `utm_source=smartlink&utm_campaign=ABC123&deferred_link=<token>`
  String? _extractDeferredLinkToken(String referrerUrl) {
    try {
      // The referrer URL is URL-encoded query parameters
      // We need to parse it as if it were query parameters
      final uri = Uri.parse('http://dummy?$referrerUrl');
      return uri.queryParameters['deferred_link'];
    } catch (e) {
      SmartLinkLogger.warning(
          'Error parsing referrer URL: $e, trying alternate method');

      // Fallback: Try to extract using string manipulation
      final match = RegExp(r'deferred_link=([^&]+)').firstMatch(referrerUrl);
      if (match != null) {
        return Uri.decodeComponent(match.group(1)!);
      }

      return null;
    }
  }

  /// Check if we have UTM parameters from SmartLink
  bool hasSmartLinkUtm() {
    if (_rawReferrer == null) return false;
    return _rawReferrer!.contains('utm_source=smartlink');
  }

  /// Get UTM source from referrer
  String? getUtmSource() {
    if (_rawReferrer == null) return null;
    try {
      final uri = Uri.parse('http://dummy?$_rawReferrer');
      return uri.queryParameters['utm_source'];
    } catch (e) {
      return null;
    }
  }

  /// Get UTM campaign from referrer
  String? getUtmCampaign() {
    if (_rawReferrer == null) return null;
    try {
      final uri = Uri.parse('http://dummy?$_rawReferrer');
      return uri.queryParameters['utm_campaign'];
    } catch (e) {
      return null;
    }
  }

  /// Get all UTM parameters from install referrer
  ///
  /// Returns UTMParams with all 5 standard UTM fields extracted from the
  /// Android Play Install Referrer string.
  ///
  /// Example referrer format:
  /// `utm_source=facebook&utm_campaign=summer_sale&utm_medium=cpc&deferred_link=<token>`
  ///
  /// Returns empty UTMParams if referrer is not available or has no UTM parameters.
  UTMParams getUTMParams() {
    if (_rawReferrer == null) {
      return const UTMParams.empty();
    }

    if (_cachedUTM != null) {
      return _cachedUTM!;
    }

    try {
      final utm = UTMParams.fromQueryString(_rawReferrer!);
      _cachedUTM = utm;
      return utm ?? const UTMParams.empty();
    } catch (e) {
      SmartLinkLogger.error('Failed to extract UTM from referrer', e);
      return const UTMParams.empty();
    }
  }

  /// Cache UTM parameters from referrer to local storage
  ///
  /// Called automatically when install referrer is retrieved.
  /// UTM parameters are persisted so they can be accessed later for attribution.
  Future<void> _cacheUTMParams() async {
    final utm = getUTMParams();
    if (utm.isNotEmpty) {
      try {
        await _storage.saveData(_keyInstallUTM, utm.toJson());
        SmartLinkLogger.debug('UTM parameters cached: $utm');
      } catch (e) {
        SmartLinkLogger.error('Failed to cache UTM parameters', e);
      }
    }
  }

  /// Get cached UTM parameters from install (persistent)
  ///
  /// Retrieves UTM parameters that were stored when the app was installed.
  /// These remain available even after app restarts.
  ///
  /// Returns null if no cached UTM parameters are found.
  ///
  /// Example:
  /// ```dart
  /// final utm = await service.getCachedInstallUTM();
  /// if (utm != null) {
  ///   print('Installed from: ${utm.source}');
  ///   print('Campaign: ${utm.campaign}');
  /// }
  /// ```
  Future<UTMParams?> getCachedInstallUTM() async {
    try {
      final data = await _storage.getData(_keyInstallUTM);
      if (data != null) {
        return UTMParams.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      SmartLinkLogger.error('Failed to retrieve cached install UTM', e);
      return null;
    }
  }

  /// Clear cached referrer (for testing)
  void clearCache() {
    _checked = false;
    _referrerToken = null;
    _rawReferrer = null;
    _installTimestamp = null;
    _clickTimestamp = null;
    _cachedUTM = null;
  }
}

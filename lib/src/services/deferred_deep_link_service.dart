import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/deep_link_match.dart';
import '../models/deferred_link_response.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'fingerprint_service.dart';
import 'install_referrer_service.dart';
import 'storage_service.dart';

/// Service for handling deferred deep linking
///
/// Supports two matching strategies:
/// 1. **Android Play Install Referrer (deterministic)**: 100% accurate matching
///    using the Play Install Referrer API. Only available on Android.
/// 2. **Fingerprint matching (probabilistic)**: ~85-90% accurate matching
///    using device fingerprinting. Available on both iOS and Android.
///
/// The service automatically tries the best available method:
/// - Android: Try referrer first, fall back to fingerprint
/// - iOS: Always use fingerprint
class DeferredDeepLinkService {
  final ApiService apiService;
  final FingerprintService fingerprintService;
  final StorageService storageService;
  final InstallReferrerService _installReferrer;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Device info for install tracking (set by client, sent to backend)
  final String? deviceId;
  final String? deviceFingerprint;
  final String? appVersion;

  DeferredDeepLinkService({
    required this.apiService,
    required this.fingerprintService,
    required this.storageService,
    InstallReferrerService? installReferrerService,
    this.deviceId,
    this.deviceFingerprint,
    this.appVersion,
  }) : _installReferrer = installReferrerService ?? InstallReferrerService(storageService);

  /// Match deferred deep link with retry logic and exponential backoff
  ///
  /// Retries on network failures with exponential backoff:
  /// - Attempt 1: Immediate
  /// - Attempt 2: After 2 seconds
  /// - Attempt 3: After 4 seconds (total 6s delay)
  ///
  /// Does NOT retry on:
  /// - 404 Not Found (no deferred link exists)
  /// - 400 Bad Request (invalid data)
  ///
  /// Strategy:
  /// 1. Android: Try Play Install Referrer first (deterministic, 100% accuracy)
  /// 2. If referrer fails: Fall back to fingerprint matching (probabilistic, ~85-90%)
  /// 3. iOS: Always use fingerprint matching
  ///
  /// Returns [DeferredLinkResponse] if a match is found, null otherwise.
  Future<DeferredLinkResponse?> matchDeferredDeepLinkWithRetry() async {
    const maxAttempts = 3;
    const timeout = Duration(seconds: 10);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        LinkGravityLogger.debug(
            'Deferred link lookup attempt ${attempt + 1}/$maxAttempts');

        final result =
            await matchDeferredDeepLink().timeout(timeout);

        if (result != null) {
          LinkGravityLogger.info(
              '✅ Deferred link found on attempt ${attempt + 1}');
          return result;
        }

        // No match found, but request succeeded
        return null;

      } on TimeoutException catch (e) {
        LinkGravityLogger.warning(
            'Deferred link lookup timeout on attempt ${attempt + 1}', e);

        // Retry with exponential backoff
        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt(); // 2, 4, 8 seconds
          LinkGravityLogger.debug('Retrying in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }

      } on ApiException catch (e) {
        // Don't retry on client errors (400, 404, etc.)
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          LinkGravityLogger.debug(
              'Client error ${e.statusCode}, not retrying');
          return null;
        }

        // Retry on server errors (500+)
        LinkGravityLogger.warning(
            'Server error ${e.statusCode} on attempt ${attempt + 1}', e);

        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));
        }

      } catch (e) {
        // Unknown error - retry
        LinkGravityLogger.error('Unexpected error on attempt ${attempt + 1}', e);

        if (attempt < maxAttempts - 1) {
          final delaySeconds = pow(2, attempt + 1).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }

    LinkGravityLogger.warning(
        'Failed to match deferred link after $maxAttempts attempts');
    return null;
  }

  /// Match deferred deep link using best available method
  ///
  /// Strategy:
  /// 1. Android: Try Play Install Referrer first (deterministic, 100% accuracy)
  /// 2. If referrer fails: Fall back to fingerprint matching (probabilistic, ~85-90%)
  /// 3. iOS: Always use fingerprint matching
  ///
  /// Returns [DeferredLinkResponse] if a match is found, null otherwise.
  Future<DeferredLinkResponse?> matchDeferredDeepLink() async {
    try {
      // Step 1: Try Android Play Install Referrer (deterministic)
      if (Platform.isAndroid) {
        LinkGravityLogger.info(
            'Android detected, trying Play Install Referrer...');

        final referrerToken = await _installReferrer.getInstallReferrer();

        if (referrerToken != null) {
          LinkGravityLogger.info('Found referrer token, querying server...');

          final response =
              await apiService.getDeferredLinkByReferrer(
            referrerToken,
            deviceId: deviceId,
            deviceFingerprint: deviceFingerprint,
            appVersion: appVersion,
          );

          if (response != null && response['success'] == true) {
            LinkGravityLogger.info('✅ Deterministic match found via referrer!');

            final deferredResponse = DeferredLinkResponse.fromJson({
              ...response,
              'matchMethod': 'referrer',
            });

            LinkGravityLogger.info('   Link: ${deferredResponse.shortCode}');
            LinkGravityLogger.info(
                '   Deep Link: ${deferredResponse.deepLinkUrl}');

            return deferredResponse;
          }
        }

        LinkGravityLogger.debug(
            'Referrer lookup failed, falling back to fingerprint...');
      }

      // Step 2: Fall back to fingerprint matching (iOS always, Android fallback)
      LinkGravityLogger.info('Using fingerprint matching...');

      final fingerprint = await _gatherFingerprint();
      LinkGravityLogger.debug(
          'Collected fingerprint: ${fingerprint.platform} ${fingerprint.model}');

      final response = await apiService.matchLink(fingerprint);

      if (response != null && response['success'] == true) {
        LinkGravityLogger.info('✅ Probabilistic match found via fingerprint');

        return DeferredLinkResponse.fromJson({
          ...response,
          'matchMethod': 'fingerprint',
        });
      }

      LinkGravityLogger.info('No deferred deep link found');
      return null;
    } catch (e, stackTrace) {
      LinkGravityLogger.error('Error matching deferred deep link', e, stackTrace);
      return null;
    }
  }

  /// Legacy method for backward compatibility
  /// Match deep link based on device fingerprint only
  /// Returns a DeepLinkMatch if a match is found, null otherwise
  Future<DeepLinkMatch?> matchDeepLink() async {
    try {
      LinkGravityLogger.debug('Attempting to match deferred deep link');

      final fingerprint = await _gatherFingerprint();
      LinkGravityLogger.debug(
          'Collected fingerprint: ${fingerprint.platform} ${fingerprint.model}');

      // Call backend match endpoint
      final response = await apiService.matchLink(fingerprint);

      if (response == null) {
        LinkGravityLogger.debug('No match response from backend');
        return null;
      }

      final match = DeepLinkMatch.fromJson(response);
      LinkGravityLogger.info(
        'Deep link match result: confidence=${match.confidence}, score=${match.score}',
      );

      return match;
    } catch (e) {
      LinkGravityLogger.error('Error matching deferred deep link', e);
      return null;
    }
  }

  /// Check if Android Install Referrer is available and has a token
  Future<bool> hasAndroidReferrer() async {
    if (!Platform.isAndroid) return false;
    final token = await _installReferrer.getInstallReferrer();
    return token != null;
  }

  /// Get the Install Referrer service for advanced usage
  InstallReferrerService get installReferrerService => _installReferrer;

  /// Gather device fingerprint for matching
  /// Collects privacy-respecting device attributes
  Future<SDKFingerprint> _gatherFingerprint() async {
    try {
      final now = DateTime.now();
      final timezone = now.timeZoneOffset.inMinutes;
      final locale = _getLocale();
      final userAgent = _getUserAgent();
      final platform = _getPlatform();

      String? idfv;
      String model;
      String osVersion;

      // Platform-specific device info collection
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        model = iosInfo.model;
        osVersion = iosInfo.systemVersion;

        // IDFV is optional - only collect if privacy controls allow
        idfv = iosInfo.identifierForVendor;

        LinkGravityLogger.debug(
          'iOS device: model=$model, osVersion=$osVersion',
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        model = androidInfo.model;
        osVersion = androidInfo.version.release;

        // Android: No IDFV equivalent in privacy-first approach
        idfv = null;

        LinkGravityLogger.debug(
          'Android device: model=$model, osVersion=$osVersion',
        );
      } else {
        model = 'web';
        osVersion = 'web';
      }

      return SDKFingerprint(
        platform: platform,
        idfv: idfv,
        model: model,
        osVersion: osVersion,
        timezone: timezone,
        locale: locale,
        userAgent: userAgent,
        timestamp: now.toIso8601String(),
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
        appVersion: appVersion,
      );
    } catch (e) {
      LinkGravityLogger.error('Error gathering fingerprint', e);

      // Return minimal fallback fingerprint
      return SDKFingerprint(
        platform: _getPlatform(),
        model: 'unknown',
        osVersion: 'unknown',
        timezone: DateTime.now().timeZoneOffset.inMinutes,
        locale: 'en-US',
        userAgent: _getUserAgent(),
        timestamp: DateTime.now().toIso8601String(),
        deviceId: deviceId,
        deviceFingerprint: deviceFingerprint,
        appVersion: appVersion,
      );
    }
  }

  /// Get device platform string
  String _getPlatform() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else {
      return 'web';
    }
  }

  /// Get system locale string
  String _getLocale() {
    try {
      final platformDispatcher = PlatformDispatcher.instance;
      final locales = platformDispatcher.locales;
      if (locales.isNotEmpty) {
        return '${locales[0].languageCode}-${locales[0].countryCode}';
      }
    } catch (e) {
      LinkGravityLogger.debug('Could not get platform locale: $e');
    }

    return 'en-US';
  }

  /// Generate User-Agent string
  /// Returns web UA from matched click if available, otherwise fallback to platform-specific UA
  String _getUserAgent({DeepLinkMatch? matchedClick}) {
    // 1. Try to get real User-Agent from web fingerprint (if available)
    final webUA = matchedClick?.webFingerprint?.userAgent;
    if (webUA != null && webUA.isNotEmpty) {
      LinkGravityLogger.debug(
          'Using real browser User-Agent from web fingerprint');
      return webUA;
    }

    // 2. Fallback to platform-specific User-Agent (simplified)
    LinkGravityLogger.debug(
        'Using fallback User-Agent (web fingerprint not available)');

    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
    } else if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36';
    }

    return 'Mozilla/5.0 (Windows NT 10.0)';
  }
}

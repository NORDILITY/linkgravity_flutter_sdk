import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Service for generating unique device fingerprints
/// Used for deferred deep linking attribution
class FingerprintService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Generate a unique, deterministic device fingerprint
  /// This fingerprint is used to match clicks before install with app opens after install
  Future<String> generateFingerprint() async {
    try {
      final attributes = await _collectDeviceAttributes();
      final fingerprint = _hashAttributes(attributes);

      SmartLinkLogger.debug('Generated fingerprint: $fingerprint');
      return fingerprint;
    } catch (e) {
      SmartLinkLogger.error('Failed to generate fingerprint', e);

      // Fallback to timestamp-based fingerprint
      final fallback = _generateFallbackFingerprint();
      SmartLinkLogger.warning('Using fallback fingerprint: $fallback');
      return fallback;
    }
  }

  /// Collect device attributes for fingerprinting
  Future<Map<String, dynamic>> _collectDeviceAttributes() async {
    final attributes = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        attributes.addAll({
          'platform': 'android',
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'androidId': androidInfo.id, // Android ID (not advertising ID)
          'sdkInt': androidInfo.version.sdkInt,
          'release': androidInfo.version.release,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        });

        SmartLinkLogger.verbose('Android device attributes collected');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        attributes.addAll({
          'platform': 'ios',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor ?? 'unknown',
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'utsname': {
            'machine': iosInfo.utsname.machine,
            'sysname': iosInfo.utsname.sysname,
          },
        });

        SmartLinkLogger.verbose('iOS device attributes collected');
      } else if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;

        attributes.addAll({
          'platform': 'web',
          'browserName': webInfo.browserName.toString(),
          'userAgent': webInfo.userAgent ?? 'unknown',
          'language': webInfo.language ?? 'unknown',
          'platform_web': webInfo.platform ?? 'unknown',
        });

        SmartLinkLogger.verbose('Web browser attributes collected');
      }

      // Add common attributes
      attributes.addAll({
        'locale': Platform.localeName,
        'timezone': DateTime.now().timeZoneOffset.inMinutes,
      });

      // Note: We intentionally avoid screen size as it can change (device rotation)
      // and may not be available early in app lifecycle
    } catch (e) {
      SmartLinkLogger.error('Error collecting device attributes', e);
    }

    return attributes;
  }

  /// Create SHA-256 hash from device attributes
  String _hashAttributes(Map<String, dynamic> attributes) {
    // Sort attributes for deterministic hashing
    final sortedKeys = attributes.keys.toList()..sort();

    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      final value = attributes[key];
      if (value != null) {
        // Handle nested objects
        if (value is Map) {
          final nestedSorted = value.entries.toList()
            ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
          for (final entry in nestedSorted) {
            buffer.write('$key.${entry.key}=${entry.value}');
            buffer.write('&');
          }
        } else {
          buffer.write('$key=$value');
          buffer.write('&');
        }
      }
    }

    final combined = buffer.toString();
    SmartLinkLogger.verbose('Fingerprint input: $combined');

    // Create SHA-256 hash
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Generate fallback fingerprint when normal fingerprinting fails
  /// This is less reliable but ensures we always have a fingerprint
  String _generateFallbackFingerprint() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode;

    final combined = 'fallback_${timestamp}_$random';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return 'fallback_${digest.toString().substring(0, 16)}';
  }

  /// Get platform name
  Future<String> getPlatformName() async {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (kIsWeb) return 'Web';
    return 'Unknown';
  }

  /// Get device model name
  Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      } else if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return webInfo.browserName.toString();
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Get OS version
  Future<String> getOSVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Check if running on a physical device (not emulator/simulator)
  Future<bool> isPhysicalDevice() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.isPhysicalDevice;
      }
      return true; // Assume physical device for other platforms
    } catch (e) {
      return true;
    }
  }
}

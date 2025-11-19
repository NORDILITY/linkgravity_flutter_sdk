import 'dart:async';
import 'package:app_links/app_links.dart';
import '../models/deep_link_data.dart';
import '../utils/logger.dart';

/// Service for handling deep links (Universal Links & App Links)
class DeepLinkService {
  /// App Links plugin instance
  final AppLinks _appLinks = AppLinks();

  /// Stream controller for deep links (public for SDK internal use)
  final StreamController<DeepLinkData> linkController =
      StreamController<DeepLinkData>.broadcast();

  /// Stream of incoming deep links
  Stream<DeepLinkData> get linkStream => linkController.stream;

  /// Initial link (for cold start)
  DeepLinkData? _initialLink;

  /// Get initial deep link
  DeepLinkData? get initialLink => _initialLink;

  /// Whether the service has been initialized
  bool _initialized = false;

  /// StreamSubscription for ongoing links
  StreamSubscription<Uri>? _subscription;

  /// Initialize deep link handling
  Future<void> initialize() async {
    if (_initialized) {
      SmartLinkLogger.warning('DeepLinkService already initialized');
      return;
    }

    SmartLinkLogger.info('Initializing deep link service...');

    try {
      // Get initial link (app opened from cold state via deep link)
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        SmartLinkLogger.info('Initial link detected: $initialUri');
        _initialLink = DeepLinkData.fromUri(initialUri);
        linkController.add(_initialLink!);
      } else {
        SmartLinkLogger.debug('No initial link found');
      }

      // Listen for incoming links (app opened from warm/hot state)
      _subscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          SmartLinkLogger.info('Deep link received: $uri');
          final deepLink = DeepLinkData.fromUri(uri);
          linkController.add(deepLink);
        },
        onError: (Object err, StackTrace stackTrace) {
          SmartLinkLogger.error('Deep link stream error', err, stackTrace);
        },
      );

      _initialized = true;
      SmartLinkLogger.info('Deep link service initialized successfully');
    } catch (e, stackTrace) {
      SmartLinkLogger.error('Failed to initialize deep link service', e, stackTrace);
      rethrow;
    }
  }

  /// Parse deep link URI into DeepLinkData
  DeepLinkData parseLink(Uri uri) {
    return DeepLinkData.fromUri(uri);
  }

  /// Check if a URI matches expected deep link format
  bool isValidDeepLink(Uri uri) {
    // Must have a scheme
    if (uri.scheme.isEmpty) return false;

    // For app/universal links, must have a host
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host.isEmpty) return false;
    }

    return true;
  }

  /// Extract link ID from deep link if present
  /// Example: smartlink://link/abc123 -> "abc123"
  String? extractLinkId(DeepLinkData deepLink) {
    // Check path for link ID
    if (deepLink.path.startsWith('/link/')) {
      final parts = deepLink.path.split('/');
      if (parts.length >= 3) {
        return parts[2];
      }
    }

    // Check query parameters
    return deepLink.getParam('linkId') ?? deepLink.getParam('link_id');
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    linkController.close();
    SmartLinkLogger.debug('DeepLinkService disposed');
  }
}

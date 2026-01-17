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

  /// Set initial deep link (used for deferred deep links)
  set initialLink(DeepLinkData? link) => _initialLink = link;

  /// Whether the service has been initialized
  bool _initialized = false;

  /// StreamSubscription for ongoing links
  StreamSubscription<Uri>? _subscription;

  /// Initialize deep link handling
  Future<void> initialize() async {
    if (_initialized) {
      LinkGravityLogger.warning('DeepLinkService already initialized');
      return;
    }

    LinkGravityLogger.info('Initializing deep link service...');

    try {
      // Get initial link (app opened from cold state via deep link)
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        LinkGravityLogger.info('Initial link detected: $initialUri');
        _initialLink = DeepLinkData.fromUri(initialUri);
        linkController.add(_initialLink!);
      } else {
        LinkGravityLogger.debug('No initial link found');
      }

      // Listen for incoming links (app opened from warm/hot state)
      _subscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          LinkGravityLogger.info('Deep link received: $uri');
          final deepLink = DeepLinkData.fromUri(uri);
          linkController.add(deepLink);
        },
        onError: (Object err, StackTrace stackTrace) {
          LinkGravityLogger.error('Deep link stream error', err, stackTrace);
        },
      );

      _initialized = true;
      LinkGravityLogger.info('Deep link service initialized successfully');
    } catch (e, stackTrace) {
      LinkGravityLogger.error(
          'Failed to initialize deep link service', e, stackTrace);
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
  /// Example: linkgravity://link/abc123 -> "abc123"
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

  /// Extract shortCode from deep link path
  ///
  /// When Android/iOS App Links intercept a link like:
  /// http://192.168.178.75:8080/tappick-test
  ///
  /// The app receives the path: /tappick-test
  ///
  /// This method extracts 'tappick-test' from the path.
  ///
  /// Returns the shortCode without the leading slash, or null if path is empty/root.
  String? extractShortCode(DeepLinkData deepLink) {
    if (deepLink.path.isEmpty || deepLink.path == '/') {
      return null;
    }

    // Remove leading slash and return the rest
    final path = deepLink.path.startsWith('/')
        ? deepLink.path.substring(1)
        : deepLink.path;

    // If path contains additional slashes, only take the first segment
    // e.g., /tappick-test/extra -> tappick-test
    final segments = path.split('/');
    return segments.isNotEmpty ? segments[0] : null;
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    linkController.close();
    LinkGravityLogger.debug('DeepLinkService disposed');
  }
}

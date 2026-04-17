import 'dart:async';
import 'package:app_links/app_links.dart';
import '../utils/logger.dart';

/// Service for handling deep links (Universal Links & App Links).
///
/// Emits raw link strings from the OS. Shortcode resolution and navigation
/// happen in [LinkGravityClient.processDeepLink]. Pre-resolved links (from
/// deferred deep link matching) go through [resolvedLinkStream] so the client
/// can skip the /resolve call.
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  /// Stream of unresolved deep link strings from the OS (warm start).
  final StreamController<String> linkController =
      StreamController<String>.broadcast();
  Stream<String> get linkStream => linkController.stream;

  /// Stream of pre-resolved deep link paths (e.g. from a deferred deep link
  /// match where the backend already resolved the shortcode).
  final StreamController<String> resolvedLinkController =
      StreamController<String>.broadcast();
  Stream<String> get resolvedLinkStream => resolvedLinkController.stream;

  /// Initial link captured on cold start. Consumed once by the client.
  String? initialLink;

  /// True when [initialLink] is already resolved and should skip /resolve.
  bool initialLinkResolved = false;

  bool _initialized = false;
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize() async {
    if (_initialized) {
      LinkGravityLogger.warning('DeepLinkService already initialized');
      return;
    }

    LinkGravityLogger.info('Initializing deep link service...');

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        final link = initialUri.toString();
        LinkGravityLogger.info('Initial link detected: $link');
        initialLink = link;
        linkController.add(link);
      }

      _subscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          final link = uri.toString();
          LinkGravityLogger.info('Deep link received: $link');
          linkController.add(link);
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

  void dispose() {
    _subscription?.cancel();
    linkController.close();
    resolvedLinkController.close();
    LinkGravityLogger.debug('DeepLinkService disposed');
  }
}

/// LinkGravity Flutter SDK
///
/// A comprehensive SDK for deferred deep linking, link generation,
/// and app-to-app attribution. Compatible with FlutterFlow.
///
/// ## Features
///
/// - Link Generation (create LinkGravity links programmatically)
/// - Deep Link Handling (Universal Links & App Links)
/// - Deferred Deep Linking (install attribution + deep link)
/// - Click Tracking & Analytics
/// - App-to-App Attribution
/// - Offline Queue (track events offline, sync later)
/// - Custom Event Tracking
/// - FlutterFlow Compatible
///
/// ## Quick Start
///
/// ```dart
/// import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';
///
/// // Initialize SDK
/// final linkGravity = await LinkGravityClient.initialize(
///   baseUrl: 'https://api.linkgravity.io',
///   apiKey: 'your-api-key',
/// );
///
/// // Create a link
/// final link = await linkGravity.createLink(
///   LinkParams(
///     longUrl: 'https://example.com/product/123',
///     deepLinkConfig: DeepLinkConfig(
///       deepLinkPath: '/product/123',
///     ),
///   ),
/// );
///
/// // Listen for deep links
/// linkGravity.onDeepLink.listen((deepLink) {
///   print('Deep link: ${deepLink.path}');
/// });
/// ```
library linkgravity_flutter_sdk;

// Main client
export 'src/linkgravity_client.dart';
export 'src/linkgravity_config.dart';

// Models
export 'src/models/link.dart';
export 'src/models/link_params.dart';
export 'src/models/attribution.dart';
export 'src/models/analytics_event.dart';
export 'src/models/deep_link_data.dart';
export 'src/models/deep_link_match.dart';
export 'src/models/deferred_link_response.dart';
export 'src/models/utm_params.dart';
export 'src/models/route_action.dart';

// Services (for advanced usage)
export 'src/services/api_service.dart' show ApiException;
export 'src/services/install_referrer_service.dart';
export 'src/services/skadnetwork_service.dart';
export 'src/services/idfa_service.dart';

// Utilities
export 'src/utils/logger.dart' show LogLevel, LogEntry, LogObserver, LinkGravityLogger;
export 'src/utils/validators.dart';

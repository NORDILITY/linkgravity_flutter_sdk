/// SmartLink Flutter SDK
///
/// A comprehensive SDK for deferred deep linking, link generation,
/// and app-to-app attribution. Compatible with FlutterFlow.
///
/// ## Features
///
/// - 🔗 Link Generation (create SmartLinks programmatically)
/// - 📱 Deep Link Handling (Universal Links & App Links)
/// - ⏰ Deferred Deep Linking (install attribution + deep link)
/// - 📊 Click Tracking & Analytics
/// - 🎯 App-to-App Attribution
/// - 📴 Offline Queue (track events offline, sync later)
/// - 📈 Custom Event Tracking
/// - ✨ FlutterFlow Compatible
///
/// ## Quick Start
///
/// ```dart
/// import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';
///
/// // Initialize SDK
/// final smartLink = await SmartLinkClient.initialize(
///   baseUrl: 'https://api.smartlink.io',
///   apiKey: 'your-api-key',
/// );
///
/// // Create a link
/// final link = await smartLink.createLink(
///   LinkParams(
///     longUrl: 'https://example.com/product/123',
///     deepLinkConfig: DeepLinkConfig(
///       deepLinkPath: '/product/123',
///     ),
///   ),
/// );
///
/// // Listen for deep links
/// smartLink.onDeepLink.listen((deepLink) {
///   print('Deep link: ${deepLink.path}');
/// });
/// ```
library smartlink_flutter_sdk;

// Main client
export 'src/smartlink_client.dart';
export 'src/smartlink_config.dart';

// Models
export 'src/models/link.dart';
export 'src/models/link_params.dart';
export 'src/models/attribution.dart';
export 'src/models/analytics_event.dart';
export 'src/models/deep_link_data.dart';
export 'src/models/deep_link_match.dart';
export 'src/models/deferred_link_response.dart';
export 'src/models/utm_params.dart';

// Services (for advanced usage)
export 'src/services/api_service.dart' show ApiException;
export 'src/services/install_referrer_service.dart';

// Utilities
export 'src/utils/logger.dart' show LogLevel;
export 'src/utils/validators.dart';

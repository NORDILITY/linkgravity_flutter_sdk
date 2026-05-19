import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linkgravity_flutter_sdk/linkgravity.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final _handledLinks = ValueNotifier<List<String>>(const []);

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const MyHomePage()),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) => ProductDetailPage(
        productId: state.pathParameters['id'] ?? 'unknown',
        queryParams: state.uri.queryParameters,
      ),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize LinkGravity SDK
  // The SDK automatically handles deferred deep linking on first launch
  await LinkGravityClient.initialize(
    baseUrl: 'http://localhost:3000',
    apiKey: 'demo-api-key',
    config: LinkGravityConfig(
      enableAnalytics: true,
      enableDeepLinking: true,
      logLevel: LogLevel.debug,
    ),
  );

  // Route regular and deferred deep links through go_router.
  LinkGravityClient.instance.handleDeepLinks(
    onNavigate: (path) {
      _handledLinks.value = [..._handledLinks.value, path];
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Navigate to: $path')),
      );
      _router.go(path);
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LinkGravity SDK Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: _router,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _createdLink;
  String? _attribution;
  int _queuedEvents = 0;

  @override
  void initState() {
    super.initState();
    _loadAttribution();
  }

  Future<void> _loadAttribution() async {
    final attribution = await LinkGravityClient.instance.getAttribution();
    if (attribution != null) {
      setState(() {
        _attribution =
            'Campaign: ${attribution.campaignId ?? "None"}\n'
            'Source: ${attribution.utmSource ?? "None"}\n'
            'Is Deferred: ${attribution.isDeferred}';
      });
    }
  }

  Future<void> _createLink() async {
    try {
      final link = await LinkGravityClient.instance.createLink(
        LinkParams(
          longUrl: 'https://example.com/product/123',
          title: 'Demo Product',
          deepLinkConfig: DeepLinkConfig(
            deepLinkPath: '/product/123',
            params: {'ref': 'demo'},
          ),
        ),
      );

      setState(() {
        _createdLink = link.shortUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _trackEvent() async {
    // Custom event name with a small properties payload. The SDK merges
    // `config.globalMetadata` and auto-attaches install-time UTM params.
    await LinkGravityClient.instance.trackEvent('demo_button_clicked', {
      'button_id': 'demo_button',
      'screen': 'home',
      'clicked_at': DateTime.now().toIso8601String(),
    });

    // Events are batched (default: 20 per batch or every 30s), so this call
    // only enqueues — use the Flush button to force an immediate send.
    setState(() => _queuedEvents++);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event queued ($_queuedEvents pending)')),
      );
    }
  }

  Future<void> _flushEvents() async {
    await LinkGravityClient.instance.flushEvents();
    setState(() => _queuedEvents = 0);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Events flushed to backend')));
    }
  }

  Future<void> _trackConversion() async {
    final success = await LinkGravityClient.instance.trackConversion(
      type: 'purchase',
      revenue: 29.99,
      currency: 'USD',
      metadata: {'product_id': '123', 'product_name': 'Demo Product'},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Conversion tracked!' : 'Failed to track conversion',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('LinkGravity SDK Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SDK Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SDK Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fingerprint: ${LinkGravityClient.instance.fingerprint?.substring(0, 16)}...',
                    ),
                    Text(
                      'Session ID: ${LinkGravityClient.instance.sessionId?.substring(0, 16)}...',
                    ),
                    Text('App Version: ${LinkGravityClient.instance.appVersion}'),
                    Text(
                      'Platform: ${Platform.isAndroid
                          ? "Android"
                          : Platform.isIOS
                          ? "iOS"
                          : "Other"}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Deferred Deep Link Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deferred Deep Linking',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Platform.isAndroid
                          ? 'Method: Play Install Referrer (100% accurate)'
                          : 'Method: Fingerprint Matching (~85-90% accurate)',
                      style: TextStyle(
                        color: Platform.isAndroid
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The SDK automatically checks for a deferred deep link '
                      'on first launch. Use handleDeepLinks() if you want '
                      'regular and deferred deep links to flow through the '
                      'same callback.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Create Link
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Link',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Creates a short link that deep links to the in-app '
                      '/product/123 page (with ?ref=demo). Tapping the '
                      'generated link — or receiving it as a deferred match '
                      'after install — routes through go_router to the '
                      'Product Details page below.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _createLink,
                      child: const Text('Create Demo Link'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.go('/product/123?ref=demo'),
                      child: const Text('Preview /product/123'),
                    ),
                    if (_createdLink != null) ...[
                      const SizedBox(height: 8),
                      Text('Created: $_createdLink'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Track Event & Conversion
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track Event enqueues a "demo_button_clicked" event via '
                      'LinkGravityClient.trackEvent(). The SDK batches events '
                      '(20 per batch or every 30s) and auto-attaches install '
                      'UTM for attribution. Use Flush to force an immediate '
                      'POST to /api/v1/events.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _trackEvent,
                          child: const Text('Track Event'),
                        ),
                        OutlinedButton(
                          onPressed: _queuedEvents == 0 ? null : _flushEvents,
                          child: Text(
                            _queuedEvents == 0
                                ? 'Flush (queue empty)'
                                : 'Flush ($_queuedEvents queued)',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _trackConversion,
                          child: const Text('Track Conversion'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Attribution
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_attribution ?? 'No attribution data'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Deep Links
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Handled Deep Links',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<List<String>>(
                      valueListenable: _handledLinks,
                      builder: (_, links, __) {
                        if (links.isEmpty) {
                          return const Text('No deep links handled yet');
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final link in links) Text('* $link'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatelessWidget {
  final String productId;
  final Map<String, String> queryParams;

  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.queryParams,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Product $productId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Product ID: $productId'),
                    const SizedBox(height: 12),
                    Text(
                      'This screen is the deep-link target for the demo '
                      'short link. It was reached via go_router after the '
                      'SDK resolved the incoming link to /product/$productId.',
                    ),
                    if (queryParams.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Query parameters',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final entry in queryParams.entries)
                        Text('  ${entry.key}: ${entry.value}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

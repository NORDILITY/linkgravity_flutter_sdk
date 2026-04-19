import 'dart:io';

import 'package:flutter/material.dart';
import 'package:linkgravity_flutter_sdk/linkgravity_flutter_sdk.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkGravity SDK Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
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
  final List<String> _deepLinks = [];

  @override
  void initState() {
    super.initState();
    _setupDeepLinkHandling();
    _loadAttribution();
  }

  void _setupDeepLinkHandling() {
    // Use the unified callback so regular and deferred deep links are handled
    // through the same entry point.
    LinkGravityClient.instance.handleDeepLinks(
      onNavigate: (path) {
        if (!mounted) return;

        setState(() {
          _deepLinks.add(path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to: $path')),
        );
      },
    );
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
    await LinkGravityClient.instance.trackEvent('button_clicked', {
      'button_id': 'demo_button',
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event tracked!')));
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
                    ElevatedButton(
                      onPressed: _createLink,
                      child: const Text('Create Demo Link'),
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
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _trackEvent,
                          child: const Text('Track Event'),
                        ),
                        const SizedBox(width: 8),
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
                    if (_deepLinks.isEmpty)
                      const Text('No deep links handled yet')
                    else
                      ..._deepLinks.map((link) => Text('* $link')),
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

import 'package:flutter/material.dart';
import 'package:smartlink_flutter_sdk/smartlink_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SmartLink SDK
  await SmartLinkClient.initialize(
    baseUrl: 'http://localhost:3000',
    apiKey: 'demo-api-key',
    config: SmartLinkConfig(
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
      title: 'SmartLink SDK Demo',
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
    _setupDeepLinkListener();
    _loadAttribution();
  }

  void _setupDeepLinkListener() {
    // Listen for deep links
    SmartLinkClient.instance.onDeepLink.listen((deepLink) {
      setState(() {
        _deepLinks.add('${deepLink.scheme}://${deepLink.host}${deepLink.path}');
      });

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deep link received: ${deepLink.path}')),
        );
      }
    });
  }

  Future<void> _loadAttribution() async {
    final attribution = await SmartLinkClient.instance.getAttribution();
    if (attribution != null) {
      setState(() {
        _attribution = 'Campaign: ${attribution.campaignId ?? "None"}\n'
            'Source: ${attribution.utmSource ?? "None"}\n'
            'Is Deferred: ${attribution.isDeferred}';
      });
    }
  }

  Future<void> _createLink() async {
    try {
      final link = await SmartLinkClient.instance.createLink(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _trackEvent() async {
    await SmartLinkClient.instance.trackEvent('button_clicked', {
      'button_id': 'demo_button',
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event tracked!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('SmartLink SDK Demo'),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Fingerprint: ${SmartLinkClient.instance.fingerprint?.substring(0, 16)}...'),
                    Text('Session ID: ${SmartLinkClient.instance.sessionId?.substring(0, 16)}...'),
                    Text('App Version: ${SmartLinkClient.instance.appVersion}'),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

            // Track Event
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _trackEvent,
                      child: const Text('Track Event'),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      'Received Deep Links',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_deepLinks.isEmpty)
                      const Text('No deep links received yet')
                    else
                      ..._deepLinks.map((link) => Text('• $link')),
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

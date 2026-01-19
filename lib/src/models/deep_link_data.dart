import 'utm_params.dart';

/// Parsed deep link data
class DeepLinkData {
  /// The path component of the deep link (e.g., "/product/123")
  final String path;

  /// Query parameters
  final Map<String, String> params;

  /// URL scheme (e.g., "https", "linkgravity", "myapp")
  final String scheme;

  /// Host/domain (if applicable)
  final String? host;

  /// Full original URI
  final Uri? originalUri;

  /// UTM parameters extracted from the deep link (if present)
  final UTMParams? utm;

  /// Whether this link is already fully resolved (avoid further resolution)
  bool isResolved;

  DeepLinkData({
    required this.path,
    required this.params,
    required this.scheme,
    this.host,
    this.originalUri,
    this.utm,
    this.isResolved = false,
  });

  /// Create from URI
  ///
  /// Automatically extracts UTM parameters from the URI if present.
  factory DeepLinkData.fromUri(Uri uri, {bool isResolved = false}) {
    // Extract UTM parameters from URI
    final utm = UTMParams.fromUri(uri);

    return DeepLinkData(
      path: uri.path,
      params: uri.queryParameters,
      scheme: uri.scheme,
      host: uri.host.isNotEmpty ? uri.host : null,
      originalUri: uri,
      utm: utm,
      isResolved: isResolved,
    );
  }

  /// Get a specific parameter value
  String? getParam(String key) => params[key];

  /// Check if parameter exists
  bool hasParam(String key) => params.containsKey(key);

  /// Create a copy with updated values
  DeepLinkData copyWith({
    String? path,
    Map<String, String>? params,
    String? scheme,
    String? host,
    Uri? originalUri,
    UTMParams? utm,
    bool? isResolved,
  }) {
    return DeepLinkData(
      path: path ?? this.path,
      params: params ?? this.params,
      scheme: scheme ?? this.scheme,
      host: host ?? this.host,
      originalUri: originalUri ?? this.originalUri,
      utm: utm ?? this.utm,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'params': params,
      'scheme': scheme,
      if (host != null) 'host': host,
      if (originalUri != null) 'originalUri': originalUri.toString(),
      if (utm != null) 'utm': utm!.toJson(),
      'isResolved': isResolved,
    };
  }

  factory DeepLinkData.fromJson(Map<String, dynamic> json) {
    return DeepLinkData(
      path: json['path'] as String,
      params: Map<String, String>.from(json['params'] as Map),
      scheme: json['scheme'] as String,
      host: json['host'] as String?,
      originalUri: json['originalUri'] != null
          ? Uri.parse(json['originalUri'] as String)
          : null,
      utm: json['utm'] != null
          ? UTMParams.fromJson(json['utm'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() {
    return 'DeepLinkData(scheme: $scheme, host: $host, path: $path, params: $params)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeepLinkData &&
        other.path == path &&
        other.scheme == scheme &&
        other.host == host;
  }

  @override
  int get hashCode => path.hashCode ^ scheme.hashCode ^ (host?.hashCode ?? 0);
}

/// Parsed deep link data
class DeepLinkData {
  /// The path component of the deep link (e.g., "/product/123")
  final String path;

  /// Query parameters
  final Map<String, String> params;

  /// URL scheme (e.g., "https", "smartlink", "myapp")
  final String scheme;

  /// Host/domain (if applicable)
  final String? host;

  /// Full original URI
  final Uri? originalUri;

  DeepLinkData({
    required this.path,
    required this.params,
    required this.scheme,
    this.host,
    this.originalUri,
  });

  /// Create from URI
  factory DeepLinkData.fromUri(Uri uri) {
    return DeepLinkData(
      path: uri.path,
      params: uri.queryParameters,
      scheme: uri.scheme,
      host: uri.host.isNotEmpty ? uri.host : null,
      originalUri: uri,
    );
  }

  /// Get a specific parameter value
  String? getParam(String key) => params[key];

  /// Check if parameter exists
  bool hasParam(String key) => params.containsKey(key);

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'params': params,
      'scheme': scheme,
      if (host != null) 'host': host,
      if (originalUri != null) 'originalUri': originalUri.toString(),
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

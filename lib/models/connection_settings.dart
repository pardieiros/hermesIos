class ConnectionSettings {
  final String host;
  final int port;
  final String token;
  final bool useHttps;

  const ConnectionSettings({
    required this.host,
    required this.port,
    required this.token,
    this.useHttps = false,
  });

  String get wsUrl {
    final scheme = useHttps ? 'wss' : 'ws';
    // Use Uri constructor with queryParameters so Dart handles all
    // special characters in the token correctly (%, #, &, etc.)
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: '/api/ws',
      queryParameters: {'token': token},
    ).toString();
  }

  String get httpUrl {
    final scheme = useHttps ? 'https' : 'http';
    return '$scheme://$host:$port';
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'token': token,
        'useHttps': useHttps,
      };

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) =>
      ConnectionSettings(
        host: json['host'] as String,
        port: json['port'] as int,
        token: json['token'] as String,
        useHttps: json['useHttps'] as bool? ?? false,
      );
}

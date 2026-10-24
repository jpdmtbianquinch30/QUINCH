import 'package:flutter/foundation.dart';

import 'media_url.dart';

/// Erreur de configuration au démarrage (URL absente ou non conforme).
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Configuration de l'application, fournie à la compilation :
/// `--dart-define=API_BASE_URL=https://api.quinch.sn/api/v1`.
/// Aucun secret n'est stocké ici : l'URL de l'API est publique.
class AppConfig {
  const AppConfig._({
    required this.apiBaseUrl,
    required this.apiHost,
    required this.media,
  });

  /// URL de base de l'API, toujours terminée par `/` (requis pour que Dio
  /// assemble correctement `base + chemin relatif`).
  final String apiBaseUrl;
  final String apiHost;
  final MediaUrl media;

  /// Valeur par défaut, utilisée UNIQUEMENT en mode debug quand rien n'est fourni :
  /// l'émulateur Android joint le PC hôte via 10.0.2.2 ; nginx expose le backend
  /// sur le port 8080 dans `docker-compose.yml`.
  static const debugDefault = 'http://10.0.2.2:8080/api/v1';

  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  factory AppConfig.fromEnvironment() =>
      AppConfig.parse(_fromEnvironment, allowInsecure: kDebugMode);

  /// `allowInsecure` n'est vrai qu'en mode debug : hors debug, HTTPS est obligatoire.
  factory AppConfig.parse(String raw, {required bool allowInsecure}) {
    var value = raw.trim();
    if (value.isEmpty) {
      if (!allowInsecure) {
        throw const ConfigException(
          'API_BASE_URL est manquant. Compilez avec --dart-define=API_BASE_URL=https://…',
        );
      }
      value = debugDefault;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ConfigException("API_BASE_URL n'est pas une URL valide.");
    }
    if (uri.userInfo.isNotEmpty) {
      throw const ConfigException(
        "API_BASE_URL ne doit contenir aucun identifiant.",
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw const ConfigException(
        "API_BASE_URL ne doit contenir ni paramètres ni fragment.",
      );
    }
    final isHttps = uri.scheme == 'https';
    final isAllowedHttp = allowInsecure && uri.scheme == 'http';
    if (!isHttps && !isAllowedHttp) {
      throw const ConfigException('HTTPS est obligatoire hors mode debug.');
    }

    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    final normalized = uri.replace(path: path).toString();
    return AppConfig._(
      apiBaseUrl: normalized,
      apiHost: uri.host,
      media: MediaUrl.fromApiBase(normalized),
    );
  }
}

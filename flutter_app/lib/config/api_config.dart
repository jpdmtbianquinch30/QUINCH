import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;

class ApiConfig {
  static const String _prefKeyServerUrl = 'quinch_server_url';

  // ---------- Configuration de production ----------
  // À définir au moment du build via --dart-define, ex :
  //   flutter build apk --release --dart-define=API_BASE_URL=https://api.quinch.sn
  // Ne JAMAIS committer une vraie URL de prod en dur ici : elle doit venir
  // du pipeline de build (CI) pour pouvoir changer sans recompiler le code.
  static const String _prodUrlFromEnv = String.fromEnvironment('API_BASE_URL');

  // ---------- Défauts de développement ----------
  // Emulator Android : 10.0.2.2 permet d'atteindre la machine hôte.
  static const String _emulatorIp = '192.168.1.5';
  static const int _devPort = 8000;

  // ---------- Runtime state ----------
  static String _serverUrl = '';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    if (kReleaseMode) {
      // En release, on exige une vraie URL HTTPS définie au build. Pas de
      // fallback silencieux vers une IP de dev en production.
      if (_prodUrlFromEnv.isEmpty) {
        throw StateError(
          'API_BASE_URL manquant pour un build release. '
          'Compiler avec --dart-define=API_BASE_URL=https://votre-domaine',
        );
      }
      if (!_prodUrlFromEnv.startsWith('https://')) {
        throw StateError('API_BASE_URL doit être en HTTPS en production.');
      }
      _serverUrl = _prodUrlFromEnv;
    } else {
      // Debug/profil : IP de dev par défaut, redéfinissable depuis l'écran
      // Réglages (utile pour tester sur un vrai téléphone sur le même
      // réseau que le PC de dev).
      _serverUrl = _prodUrlFromEnv.isNotEmpty
          ? _prodUrlFromEnv
          : 'http://$_emulatorIp:$_devPort';

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyServerUrl);
      if (saved != null && saved.isNotEmpty) {
        _serverUrl = saved;
      }
    }

    _initialized = true;
    debugPrint('[ApiConfig] FINAL serverUrl = $_serverUrl');
  }

  /// Change server URL at runtime (from Settings / login screen).
  /// Disponible uniquement en dev : en release, l'URL est figée au build.
  static Future<void> setServerUrl(String url) async {
    if (kReleaseMode) return;
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyServerUrl, _serverUrl);
    debugPrint('[ApiConfig] serverUrl updated to $_serverUrl');
  }

  /// Reset to auto-detected default (dev uniquement).
  static Future<void> resetServerUrl() async {
    if (kReleaseMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyServerUrl);
    final ip = _isEmulator ? _emulatorIp : _emulatorIp;
    _serverUrl = 'http://$ip:$_devPort';
    debugPrint('[ApiConfig] serverUrl reset to $_serverUrl');
  }

  /// Detect if we're running on an Android emulator.
  static bool get _isEmulator {
    if (!Platform.isAndroid) return false;
    final host = Platform.localHostname.toLowerCase();
    return host.contains('localhost') ||
        host.contains('emulator') ||
        host.contains('sdk') ||
        host.contains('gphone') ||
        host.contains('generic');
  }

  // ---------- Public getters ----------
  static String get serverUrl {
    assert(_initialized, 'ApiConfig.init() must be called before accessing serverUrl');
    return _serverUrl;
  }

  static String get baseUrl => '$serverUrl/api/v1';
  static String get storageUrl => '$serverUrl/storage';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Converts a relative URL to an absolute URL.
  static String resolveUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$serverUrl$url';
    return '$serverUrl/$url';
  }

  // Token storage keys
  static const String tokenKey = 'quinch_token';
  static const String userKey = 'quinch_user';

  // Pagination
  static const int defaultPerPage = 15;

  // Upload limits
  static const int maxVideoSizeMB = 500;
  static const int maxImageSizeMB = 5;
  static const int maxCoverSizeMB = 10;
  static const int maxFileSizeMB = 20;
  static const int maxAudioSizeMB = 10;
}

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ApiConfig {
  static const String _prefKeyServerUrl = 'quinch_server_url';

  // ---------- Default IPs ----------
  // Emulator uses 10.0.2.2 to reach the host machine.
  static const String _emulatorIp = '10.0.2.2';
  // Real devices use 127.0.0.1 via ADB reverse port forwarding
  // (run: adb reverse tcp:8000 tcp:8000)
  // This bypasses firewall and works regardless of network config.
  static const String _defaultRealIp = '127.0.0.1';
  static const int _port = 8000;

  // ---------- Runtime state ----------
  static String _serverUrl = '';
  static bool _initialized = false;

  /// Must be called once at app startup (before any API call).
  static Future<void> init() async {
    if (_initialized) return;

    final isEmu = _isEmulator;
    debugPrint('[ApiConfig] _isEmulator = $isEmu, hostname = ${Platform.localHostname}');

    // Always auto-detect on startup (ignore stale saved URL).
    // User can override later via login screen config.
    final ip = isEmu ? _emulatorIp : _defaultRealIp;
    _serverUrl = 'http://$ip:$_port';

    // Clear any stale saved URL
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyServerUrl);
    _initialized = true;
    debugPrint('[ApiConfig] FINAL serverUrl = $_serverUrl');
  }

  /// Change server URL at runtime (from Settings / login screen).
  static Future<void> setServerUrl(String url) async {
    // Normalize: remove trailing slash
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyServerUrl, _serverUrl);
    debugPrint('[ApiConfig] serverUrl updated to $_serverUrl');
  }

  /// Reset to auto-detected default.
  static Future<void> resetServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyServerUrl);
    final ip = _isEmulator ? _emulatorIp : _defaultRealIp;
    _serverUrl = 'http://$ip:$_port';
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

  /// When using ADB reverse port forwarding (adb reverse tcp:8000 tcp:8000),
  /// real devices can also reach the server via 127.0.0.1.
  /// This is the most reliable method that bypasses firewall issues.

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

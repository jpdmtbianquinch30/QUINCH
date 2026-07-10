import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  late Dio _dio;
  String? _token;

  // Le token d'authentification est sensible (équivalent d'un mot de passe
  // tant qu'il est valide) : il est stocké dans le Keychain (iOS) / Keystore
  // chiffré (Android) via flutter_secure_storage, jamais dans
  // SharedPreferences qui est un fichier en clair sur le disque.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiService() {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  /// Rebuild Dio with the current ApiConfig.baseUrl.
  /// Call this after ApiConfig.setServerUrl() to pick up the new URL.
  void refreshBaseUrl() {
    final currentToken = _token;
    final currentCallback = _onUnauthorized;
    _initDio();
    _token = currentToken;
    _onUnauthorized = currentCallback;
  }

  VoidCallback? _onUnauthorized;

  void setOnUnauthorized(VoidCallback callback) {
    _onUnauthorized = callback;
  }

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Future<void> loadToken() async {
    _token = await _secureStorage.read(key: ApiConfig.tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _secureStorage.write(key: ApiConfig.tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: ApiConfig.tokenKey);
  }

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.put(path, data: data, options: options);
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.delete(path, data: data, options: options);
  }

  // Upload file with multipart
  Future<Response> upload(
    String path, {
    required FormData data,
    void Function(int, int)? onSendProgress,
    Options? options,
  }) {
    return _dio.post(
      path,
      data: data,
      onSendProgress: onSendProgress,
      options: options ?? Options(contentType: 'multipart/form-data'),
    );
  }
}

typedef VoidCallback = void Function();

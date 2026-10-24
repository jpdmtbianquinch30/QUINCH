import 'dart:io';

import 'package:dio/dio.dart';

import 'auth_token_holder.dart';

/// Ajoute `Authorization: Bearer …` uniquement pour les requêtes vers l'hôte de l'API.
/// Le jeton n'est jamais envoyé vers un autre domaine.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._apiHost);

  final AuthTokenHolder _tokens;
  final String _apiHost;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.token;
    if (token != null && options.uri.host == _apiHost) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Reprise limitée des requêtes GET sur erreur réseau, délai de lecture ou
/// 502/504. Jamais pour POST/PUT/DELETE (risque de double action), ni pour 503
/// (maintenance), ni pour un échec TLS (inutile et à ne jamais contourner).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  static const _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = (request.extra[_attemptKey] as int?) ?? 0;
    if (!_shouldRetry(err) || attempt >= maxRetries) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(baseDelay * (attempt + 1));
    request.extra[_attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<Object?>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') {
      return false;
    }
    if (err.error is TlsException) {
      return false;
    }
    final type = err.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError) {
      return true;
    }
    if (type == DioExceptionType.badResponse) {
      final status = err.response?.statusCode;
      return status == 502 || status == 504;
    }
    return false;
  }
}

import 'dart:io';

import 'package:dio/dio.dart';

import 'api_error.dart';
import 'auth_token_holder.dart';

/// Appelé quand le serveur invalide la session (401, compte banni ou suspendu)
/// pour une requête qui portait un jeton.
typedef SessionInvalidHandler = void Function(ApiError error);

/// Convertit une erreur Dio en `ApiError`. Les widgets ne voient jamais Dio.
ApiError mapDioException(DioException e) {
  final type = e.type;
  // Toutes les variantes de délai dépassé (connexion, envoi, réception, et
  // transformation selon la version de Dio). Évite un `switch` exhaustif qui
  // casse quand Dio ajoute une valeur à l'énumération.
  if (type.name.endsWith('Timeout')) {
    return ApiError.timeout();
  }
  if (type == DioExceptionType.badResponse) {
    return ApiError.fromResponse(e.response?.statusCode, e.response?.data);
  }
  if (type == DioExceptionType.badCertificate || e.error is TlsException) {
    return ApiError.tls();
  }
  if (type == DioExceptionType.cancel) {
    return ApiError.cancelled();
  }
  return ApiError.network();
}

/// Seule porte d'entrée HTTP de l'application. Renvoie le corps JSON décodé
/// (`Object?`) ou lève une `ApiError`.
class ApiClient {
  ApiClient({
    required Dio dio,
    required AuthTokenHolder tokens,
    SessionInvalidHandler? onSessionInvalid,
  }) : _dio = dio,
       _tokens = tokens,
       _onSessionInvalid = onSessionInvalid;

  final Dio _dio;
  final AuthTokenHolder _tokens;
  final SessionInvalidHandler? _onSessionInvalid;

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    CancelToken? cancelToken,
  }) => _send('GET', path, query: query, cancelToken: cancelToken);

  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, Object?>? query,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => _send(
    'POST',
    path,
    data: data,
    query: query,
    options: options,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
  );

  Future<Object?> put(
    String path, {
    Object? data,
    Map<String, Object?>? query,
  }) => _send('PUT', path, data: data, query: query);

  Future<Object?> patch(
    String path, {
    Object? data,
    Map<String, Object?>? query,
  }) => _send('PATCH', path, data: data, query: query);

  Future<Object?> delete(
    String path, {
    Object? data,
    Map<String, Object?>? query,
  }) => _send('DELETE', path, data: data, query: query);

  Future<Object?> _send(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final carriedToken = _tokens.token != null;
    final effective = (options ?? Options()).copyWith(method: method);
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: effective,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      return response.data;
    } on DioException catch (e) {
      final error = mapDioException(e);
      if (carriedToken && _invalidatesSession(error)) {
        _onSessionInvalid?.call(error);
      }
      Error.throwWithStackTrace(error, e.stackTrace);
    }
  }

  static bool _invalidatesSession(ApiError error) =>
      error.kind == ApiErrorKind.unauthorized ||
      error.kind == ApiErrorKind.accountBanned ||
      error.kind == ApiErrorKind.accountSuspended;
}

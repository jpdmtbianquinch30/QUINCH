import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_token_holder.dart';
import 'interceptors.dart';

/// Construit le client Dio.
///
/// Sécurité : on ne fournit JAMAIS de `badCertificateCallback` ni de
/// `HttpOverrides` : la validation TLS du système reste intacte.
/// Aucun `LogInterceptor` : ni en-têtes ni corps de requête ne sont journalisés.
/// `sendTimeout` n'est pas fixé globalement (inutile pour les GET) ; il sera
/// défini par requête pour les envois de médias (étape 6).
Dio createDio({
  required AppConfig config,
  required AuthTokenHolder tokens,
  HttpClientAdapter? adapter,
  Duration retryBaseDelay = const Duration(milliseconds: 400),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, Object>{'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.addAll([
    AuthInterceptor(tokens, config.apiHost),
    RetryInterceptor(dio, baseDelay: retryBaseDelay),
  ]);
  return dio;
}

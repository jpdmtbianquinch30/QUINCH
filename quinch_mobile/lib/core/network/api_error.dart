import '../json/json_utils.dart';

/// Classement des erreurs de l'API, d'après le code lu dans le backend.
///
/// IMPORTANT : un 404 ne prouve jamais, à lui seul, qu'une fonctionnalité est
/// désactivée. Le middleware `feature:*` fait `abort(404)` sans message, mais un
/// 404 sans message peut avoir d'autres causes. Les variantes 404 ne sont que
/// des indices ; la décision revient au service de disponibilité (étape 4),
/// qui ne l'applique qu'à des routes connues comme sous drapeau.
enum ApiErrorKind {
  network,
  timeout,
  tls,
  unauthorized,
  accountBanned,
  accountSuspended,
  emailNotVerified,
  forbidden,
  validation,
  rateLimited,
  maintenance,
  notFoundEmptyMessage,
  notFoundRouteMissing,
  notFoundResource,
  notFoundOther,
  server,
  unknown,
}

class ApiError implements Exception {
  const ApiError({
    required this.kind,
    this.statusCode,
    this.serverMessage,
    this.code,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final ApiErrorKind kind;
  final int? statusCode;

  /// Message renvoyé par le serveur (déjà en français), s'il existe.
  final String? serverMessage;

  /// Champ `error` du backend : account_banned, email_not_verified, maintenance,
  /// invalid_otp, otp_rate_limited, premium_coming_soon, phone_taken, etc.
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final int? retryAfterSeconds;

  factory ApiError.network() => const ApiError(kind: ApiErrorKind.network);
  factory ApiError.timeout() => const ApiError(kind: ApiErrorKind.timeout);

  /// Échec de la connexion sécurisée (certificat ou protocole). Jamais contourné.
  factory ApiError.tls() => const ApiError(kind: ApiErrorKind.tls);

  factory ApiError.cancelled() => const ApiError(kind: ApiErrorKind.unknown);

  factory ApiError.fromResponse(int? status, Object? body) {
    final map = asMap(body);
    final message = asStringOrNull(map['message']);
    final code = asStringOrNull(map['error']);
    final fields = <String, List<String>>{};
    asMap(map['errors']).forEach((k, v) => fields[k] = asStringList(v));
    final retry = map['retry_after'] == null ? null : asInt(map['retry_after']);

    final ApiErrorKind kind;
    if (status == 401) {
      kind = ApiErrorKind.unauthorized;
    } else if (status == 403) {
      kind = switch (code) {
        'account_banned' => ApiErrorKind.accountBanned,
        'account_suspended' => ApiErrorKind.accountSuspended,
        'email_not_verified' => ApiErrorKind.emailNotVerified,
        _ => ApiErrorKind.forbidden,
      };
    } else if (status == 404) {
      kind = _classify404(message);
    } else if (status == 422) {
      kind = ApiErrorKind.validation;
    } else if (status == 429) {
      kind = ApiErrorKind.rateLimited;
    } else if (status == 503 && code == 'maintenance') {
      kind = ApiErrorKind.maintenance;
    } else if (status != null && status >= 500) {
      kind = ApiErrorKind.server;
    } else {
      kind = ApiErrorKind.unknown;
    }
    return ApiError(
      kind: kind,
      statusCode: status,
      serverMessage: message,
      code: code,
      fieldErrors: fields,
      retryAfterSeconds: retry,
    );
  }

  static ApiErrorKind _classify404(String? message) {
    if (message == null) return ApiErrorKind.notFoundEmptyMessage;
    final m = message.toLowerCase();
    if (m.startsWith('the route ') && m.contains('could not be found')) {
      return ApiErrorKind.notFoundRouteMissing;
    }
    if (m.contains('no query results') ||
        m.contains('introuvable') ||
        m.contains('not found')) {
      return ApiErrorKind.notFoundResource;
    }
    return ApiErrorKind.notFoundOther;
  }

  /// Première erreur de validation (d'un champ donné, ou du premier champ).
  String? firstFieldError([String? field]) {
    if (field != null) {
      final list = fieldErrors[field];
      return (list == null || list.isEmpty) ? null : list.first;
    }
    for (final list in fieldErrors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return null;
  }

  /// Texte à afficher. Ne contient jamais de donnée sensible.
  String get userMessage {
    final fromField = firstFieldError();
    if (fromField != null) return fromField;
    final m = serverMessage;
    if (m != null && m.isNotEmpty && kind != ApiErrorKind.server) return m;
    return switch (kind) {
      ApiErrorKind.network => 'Connexion impossible. Vérifiez votre réseau.',
      ApiErrorKind.timeout =>
        'Le serveur met trop de temps à répondre. Réessayez.',
      ApiErrorKind.tls =>
        'Connexion sécurisée impossible : le certificat du serveur est refusé.',
      ApiErrorKind.unauthorized => 'Votre session a expiré. Reconnectez-vous.',
      ApiErrorKind.maintenance =>
        'QUINCH est en maintenance. Revenez dans quelques instants.',
      ApiErrorKind.rateLimited =>
        'Trop de tentatives. Réessayez dans un instant.',
      ApiErrorKind.server =>
        'Une erreur est survenue côté serveur. Réessayez plus tard.',
      ApiErrorKind.forbidden => "Vous n'avez pas accès à cette action.",
      _ => 'Une erreur est survenue.',
    };
  }

  @override
  String toString() => 'ApiError($kind, status: $statusCode, code: $code)';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';

void main() {
  group('ApiError.fromResponse', () {
    test('401 : non authentifié', () {
      final e = ApiError.fromResponse(401, <String, dynamic>{
        'message': 'Unauthenticated.',
      });
      expect(e.kind, ApiErrorKind.unauthorized);
    });

    test('403 : codes du backend', () {
      expect(
        ApiError.fromResponse(403, <String, dynamic>{
          'error': 'account_banned',
        }).kind,
        ApiErrorKind.accountBanned,
      );
      expect(
        ApiError.fromResponse(403, <String, dynamic>{
          'error': 'account_suspended',
        }).kind,
        ApiErrorKind.accountSuspended,
      );
      expect(
        ApiError.fromResponse(403, <String, dynamic>{
          'error': 'email_not_verified',
        }).kind,
        ApiErrorKind.emailNotVerified,
      );
      expect(
        ApiError.fromResponse(403, <String, dynamic>{
          'message': 'Interdit',
        }).kind,
        ApiErrorKind.forbidden,
      );
    });

    test(
      '404 : trois indices distincts, aucune conclusion sur les drapeaux',
      () {
        expect(
          ApiError.fromResponse(404, <String, dynamic>{'message': ''}).kind,
          ApiErrorKind.notFoundEmptyMessage,
        );
        expect(
          ApiError.fromResponse(404, null).kind,
          ApiErrorKind.notFoundEmptyMessage,
        );
        expect(
          ApiError.fromResponse(404, <String, dynamic>{
            'message': 'The route api/v1/negotiations could not be found.',
          }).kind,
          ApiErrorKind.notFoundRouteMissing,
        );
        expect(
          ApiError.fromResponse(404, <String, dynamic>{
            'message': 'No query results for model [App\\Models\\User].',
          }).kind,
          ApiErrorKind.notFoundResource,
        );
        expect(
          ApiError.fromResponse(404, <String, dynamic>{
            'message': 'Annonce introuvable.',
          }).kind,
          ApiErrorKind.notFoundResource,
        );
        expect(
          ApiError.fromResponse(404, <String, dynamic>{
            'message': 'Autre chose',
          }).kind,
          ApiErrorKind.notFoundOther,
        );
      },
    );

    test('409 : reste une erreur inconnue avec le message du serveur', () {
      final e = ApiError.fromResponse(409, <String, dynamic>{
        'message': 'Déjà signalé.',
      });
      expect(e.kind, ApiErrorKind.unknown);
      expect(e.userMessage, 'Déjà signalé.');
    });

    test('422 : erreurs par champ', () {
      final e = ApiError.fromResponse(422, <String, dynamic>{
        'message': 'invalide',
        'errors': <String, dynamic>{
          'email': <String>['Email invalide'],
          'password': <String>['Trop court', 'Majuscule requise'],
        },
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.firstFieldError('password'), 'Trop court');
      expect(e.firstFieldError('absent'), isNull);
      expect(e.userMessage, 'Email invalide');
    });

    test('422 avec code métier', () {
      final e = ApiError.fromResponse(422, <String, dynamic>{
        'error': 'invalid_otp',
        'message': 'Code invalide',
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.code, 'invalid_otp');
    });

    test('429 : limitation, avec délai éventuel', () {
      final e = ApiError.fromResponse(429, <String, dynamic>{
        'error': 'otp_rate_limited',
        'message': 'Patientez',
        'retry_after': 60,
      });
      expect(e.kind, ApiErrorKind.rateLimited);
      expect(e.retryAfterSeconds, 60);
    });

    test('429 de connexion : erreur sur le champ email', () {
      final e = ApiError.fromResponse(429, <String, dynamic>{
        'message': 'Trop de tentatives',
        'errors': <String, dynamic>{
          'email': <String>['Trop de tentatives de connexion.'],
        },
      });
      expect(e.kind, ApiErrorKind.rateLimited);
      expect(e.userMessage, 'Trop de tentatives de connexion.');
    });

    test('503 : maintenance seulement avec le code dédié', () {
      expect(
        ApiError.fromResponse(503, <String, dynamic>{
          'error': 'maintenance',
        }).kind,
        ApiErrorKind.maintenance,
      );
      expect(
        ApiError.fromResponse(503, <String, dynamic>{}).kind,
        ApiErrorKind.server,
      );
    });

    test('5xx : erreur serveur avec message générique', () {
      final e = ApiError.fromResponse(500, <String, dynamic>{
        'message': 'SQLSTATE[...] détail interne',
      });
      expect(e.kind, ApiErrorKind.server);
      expect(e.userMessage, isNot(contains('SQLSTATE')));
    });

    test('corps inattendu (texte) : pas d\'exception', () {
      final e = ApiError.fromResponse(500, '<html>Erreur</html>');
      expect(e.kind, ApiErrorKind.server);
    });
  });

  test('erreurs de transport', () {
    expect(ApiError.network().userMessage, isNotEmpty);
    expect(ApiError.timeout().kind, ApiErrorKind.timeout);
    expect(ApiError.tls().kind, ApiErrorKind.tls);
  });
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';

import '../support/fakes.dart';

void main() {
  late AuthTokenHolder tokens;
  late List<ApiError> invalidations;

  ApiClient buildClient(FakeAdapter adapter) {
    final config = AppConfig.parse(
      'https://api.quinch.sn/api/v1',
      allowInsecure: false,
    );
    final dio = createDio(
      config: config,
      tokens: tokens,
      adapter: adapter,
      retryBaseDelay: Duration.zero,
    );
    return ApiClient(
      dio: dio,
      tokens: tokens,
      onSessionInvalid: invalidations.add,
    );
  }

  setUp(() {
    tokens = AuthTokenHolder();
    invalidations = <ApiError>[];
  });

  group('en-têtes et URL', () {
    test(
      'assemble base + chemin relatif et envoie le jeton à l\'hôte de l\'API',
      () async {
        tokens.token = 'abc';
        final adapter = FakeAdapter(
          (o) async => jsonResponse(<String, dynamic>{'ok': true}, 200),
        );
        final result = await buildClient(adapter).get('products/feed');
        expect(result, <String, dynamic>{'ok': true});
        final request = adapter.requests.single;
        expect(
          request.uri.toString(),
          'https://api.quinch.sn/api/v1/products/feed',
        );
        expect(request.headers['Authorization'], 'Bearer abc');
        expect(request.headers['Accept'], 'application/json');
      },
    );

    test('sans jeton : pas d\'en-tête Authorization', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{}, 200),
      );
      await buildClient(adapter).get('public-config');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('le jeton n\'est jamais envoyé à un autre domaine', () async {
      tokens.token = 'abc';
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{}, 200),
      );
      await buildClient(adapter).get('https://autre-domaine.example/x');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('erreurs HTTP', () {
    Future<ApiError> errorOf(int status, Object? body, {String? token}) async {
      tokens.token = token;
      final adapter = FakeAdapter((o) async => jsonResponse(body, status));
      try {
        await buildClient(adapter).get('x');
      } on ApiError catch (e) {
        return e;
      }
      fail('Une ApiError était attendue');
    }

    test('422 : erreurs de validation', () async {
      final e = await errorOf(422, <String, dynamic>{
        'message': 'invalide',
        'errors': <String, dynamic>{
          'email': <String>['Invalide'],
        },
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.firstFieldError('email'), 'Invalide');
    });

    test('401 avec jeton : session invalidée', () async {
      final e = await errorOf(401, <String, dynamic>{
        'message': 'Unauthenticated.',
      }, token: 'abc');
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(invalidations, hasLength(1));
    });

    test('401 sans jeton : pas d\'invalidation de session', () async {
      final e = await errorOf(401, <String, dynamic>{
        'message': 'Unauthenticated.',
      });
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(invalidations, isEmpty);
    });

    test('403 compte banni : session invalidée', () async {
      final e = await errorOf(403, <String, dynamic>{
        'error': 'account_banned',
      }, token: 'abc');
      expect(e.kind, ApiErrorKind.accountBanned);
      expect(invalidations, hasLength(1));
    });

    test('403 sans code : pas d\'invalidation', () async {
      final e = await errorOf(403, <String, dynamic>{
        'message': 'Interdit',
      }, token: 'abc');
      expect(e.kind, ApiErrorKind.forbidden);
      expect(invalidations, isEmpty);
    });

    test('404 sans message : simple indice, session intacte', () async {
      final e = await errorOf(404, <String, dynamic>{
        'message': '',
      }, token: 'abc');
      expect(e.kind, ApiErrorKind.notFoundEmptyMessage);
      expect(invalidations, isEmpty);
    });

    test('409', () async {
      final e = await errorOf(409, <String, dynamic>{'message': 'Déjà fait'});
      expect(e.statusCode, 409);
      expect(e.userMessage, 'Déjà fait');
    });

    test('429', () async {
      final e = await errorOf(429, <String, dynamic>{
        'message': 'Trop vite',
        'retry_after': 30,
      });
      expect(e.kind, ApiErrorKind.rateLimited);
      expect(e.retryAfterSeconds, 30);
    });

    test('503 maintenance : pas de reprise automatique', () async {
      final adapter = FakeAdapter(
        (o) async =>
            jsonResponse(<String, dynamic>{'error': 'maintenance'}, 503),
      );
      await expectLater(
        buildClient(adapter).get('x'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.maintenance,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('500 : erreur serveur, pas de reprise', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{}, 500),
      );
      await expectLater(
        buildClient(adapter).get('x'),
        throwsA(
          isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.server),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('reprises', () {
    test('GET : une panne réseau passagère est reprise', () async {
      var calls = 0;
      final adapter = FakeAdapter((o) async {
        calls++;
        if (calls == 1) throw connectionError(o);
        return jsonResponse(<String, dynamic>{'ok': true}, 200);
      });
      final result = await buildClient(adapter).get('x');
      expect(result, <String, dynamic>{'ok': true});
      expect(adapter.requests, hasLength(2));
    });

    test('GET : 502 repris', () async {
      var calls = 0;
      final adapter = FakeAdapter((o) async {
        calls++;
        return calls == 1
            ? jsonResponse(<String, dynamic>{}, 502)
            : jsonResponse(<String, dynamic>{'ok': true}, 200);
      });
      await buildClient(adapter).get('x');
      expect(adapter.requests, hasLength(2));
    });

    test('GET : abandon après 2 reprises', () async {
      final adapter = FakeAdapter((o) async => throw connectionError(o));
      await expectLater(
        buildClient(adapter).get('x'),
        throwsA(
          isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.network),
        ),
      );
      expect(adapter.requests, hasLength(3));
    });

    test('POST : jamais repris', () async {
      final adapter = FakeAdapter((o) async => throw connectionError(o));
      await expectLater(
        buildClient(adapter).post('x', data: <String, Object?>{'a': 1}),
        throwsA(
          isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.network),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('délai dépassé en POST : ApiError.timeout, sans reprise', () async {
      final adapter = FakeAdapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        buildClient(adapter).post('x'),
        throwsA(
          isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('échec TLS : classé tls et jamais repris', () async {
      final adapter = FakeAdapter(
        (o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.unknown,
          error: const HandshakeException('certificat refusé'),
        ),
      );
      await expectLater(
        buildClient(adapter).get('x'),
        throwsA(
          isA<ApiError>().having((e) => e.kind, 'kind', ApiErrorKind.tls),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  });
}

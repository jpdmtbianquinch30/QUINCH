import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/premium.dart';
import 'package:quinch_mobile/data/repositories/premium_repository.dart';
import 'package:quinch_mobile/data/repositories/ranking_repository.dart';

import '../support/fakes.dart';

// Paramètres et corps ENVOYÉS, et lecture de réponses simulées d'après le code
// du backend. Ils ne prouvent pas le comportement d'un vrai serveur.

void main() {
  late FakeAdapter adapter;
  late ApiClient api;

  void build(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = FakeAdapter(handler);
    final config = AppConfig.parse(
      'https://api.quinch.sn/api/v1',
      allowInsecure: false,
    );
    final tokens = AuthTokenHolder();
    api = ApiClient(
      dio: createDio(config: config, tokens: tokens, adapter: adapter),
      tokens: tokens,
    );
  }

  RequestOptions last() => adapter.requests.last;

  group('PremiumRepository', () {
    test('config publique', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'beta': true,
          'listing_fee_with_video': 0,
          'premium_offer_slots': 100,
          'premium_payments': false,
        }, 200),
      );
      final config = await PremiumRepository(api).config();
      expect(last().uri.path, '/api/v1/public-config');
      expect(config.beta, isTrue);
      expect(config.premiumPayments, isFalse);
    });

    test('formules et statut', () async {
      build(
        (o) async => o.uri.path.endsWith('/plans')
            ? jsonResponse(<String, dynamic>{
                'plans': <Object?>[
                  <String, dynamic>{
                    'id': 'monthly',
                    'label': 'Mensuel',
                    'price': 2000,
                    'currency': 'XOF',
                  },
                ],
              }, 200)
            : jsonResponse(<String, dynamic>{
                'is_premium': true,
                'plan': 'annual',
                'expires_at': '2027-01-01T00:00:00.000000Z',
                'days_remaining': 70,
                'pending_subscription': null,
              }, 200),
      );
      final repo = PremiumRepository(api);
      final plans = await repo.plans();
      expect(plans.single.price, 2000);
      final status = await repo.status();
      expect(status.isPremium, isTrue);
      expect(status.daysRemaining, 70);
      expect(status.pendingSubscription, isNull);
    });

    test('offre de lancement : lecture et candidature', () async {
      build(
        (o) async => o.method == 'GET'
            ? jsonResponse(<String, dynamic>{
                'slots_total': 100,
                'slots_left': 12,
                'days': 90,
                'my_status': 'pending',
              }, 200)
            : jsonResponse(<String, dynamic>{
                'message': 'Candidature envoyée.',
                'my_status': 'pending',
              }, 201),
      );
      final repo = PremiumRepository(api);
      final offer = await repo.offer();
      expect(offer.myStatus, 'pending');
      final applied = await repo.applyOffer();
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/premium/offer/apply');
      expect(applied.myStatus, 'pending');
      expect(applied.message, 'Candidature envoyée.');
    });

    test(
      'abonnement : formule et mode de paiement envoyés, adresse https renvoyée',
      () async {
        build(
          (o) async => jsonResponse(<String, dynamic>{
            'message': 'Redirection vers le paiement.',
            'subscription': <String, dynamic>{'id': 's1', 'status': 'pending'},
            'payment_url': 'https://pay.example/session/abc',
          }, 201),
        );
        final start = await PremiumRepository(api).subscribe('monthly');
        expect(last().method, 'POST');
        expect(last().uri.path, '/api/v1/premium/subscribe');
        expect(last().data, <String, Object?>{
          'plan': 'monthly',
          'payment_method': 'wave',
        });
        expect(start?.paymentUrl.host, 'pay.example');
      },
    );

    test(
      'abonnement : une adresse non sécurisée ou absente n\'est jamais renvoyée',
      () async {
        build(
          (o) async => jsonResponse(<String, dynamic>{
            'payment_url': 'http://pay.example/x',
          }, 201),
        );
        expect(await PremiumRepository(api).subscribe('annual'), isNull);

        build(
          (o) async => jsonResponse(<String, dynamic>{
            'message': 'Redirection vers le paiement.',
          }, 201),
        );
        expect(await PremiumRepository(api).subscribe('annual'), isNull);
      },
    );

    test('abonnement coupé en bêta : erreur 403 explicite', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message':
              "Le mode de paiement n'est pas actif actuellement pour la version bêta.",
          'error': 'premium_coming_soon',
        }, 403),
      );
      await expectLater(
        PremiumRepository(api).subscribe('monthly'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'premium_coming_soon')
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden),
        ),
      );
    });
  });

  group('RankingRepository', () {
    test('préférences et mise à jour (PATCH)', () async {
      build(
        (o) async => o.method == 'GET'
            ? jsonResponse(<String, dynamic>{
                'is_premium': true,
                'ranking_opt_in': false,
                'ranking_anonymous': true,
              }, 200)
            : jsonResponse(<String, dynamic>{
                'ranking_opt_in': true,
                'ranking_anonymous': true,
              }, 200),
      );
      final repo = RankingRepository(api);
      final prefs = await repo.preferences();
      expect(prefs.isPremium, isTrue);
      expect(prefs.optIn, isFalse);
      expect(prefs.anonymous, isTrue);

      final saved = await repo.updatePreferences(optIn: true, anonymous: true);
      expect(last().method, 'PATCH');
      expect(last().uri.path, '/api/v1/rankings/preferences');
      expect(last().data, <String, Object?>{'opt_in': true, 'anonymous': true});
      expect(saved.optIn, isTrue);
    });

    test('classements d\'utilisateurs : un chemin par type', () async {
      build(
        (o) async =>
            jsonResponse(<String, dynamic>{'ranking': <Object?>[]}, 200),
      );
      final repo = RankingRepository(api);
      await repo.users(RankingKind.sellers);
      expect(last().uri.path, '/api/v1/rankings/sellers');
      await repo.users(RankingKind.profiles);
      expect(last().uri.path, '/api/v1/rankings/profiles');
      await repo.users(RankingKind.followers);
      expect(last().uri.path, '/api/v1/rankings/followers');
      await expectLater(repo.users(RankingKind.products), throwsArgumentError);
    });

    test('classement d\'annonces : forme propre', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'ranking': <Object?>[
            <String, dynamic>{
              'rank': 1,
              'product_id': 'p1',
              'product_slug': 'robe-wax',
              'product_title': 'Robe wax',
              'product_image': 'https://api.quinch.sn/i.jpg',
              'view_count': 321,
              'anonymous': false,
              'seller_username': 'fatou',
              'seller_name': 'Fatou Sow',
            },
          ],
        }, 200),
      );
      final list = await RankingRepository(api).products();
      expect(last().uri.path, '/api/v1/rankings/products');
      expect(list.single.title, 'Robe wax');
      expect(list.single.viewCount, 321);
      expect(list.single.sellerUsername, 'fatou');
    });

    test('non Premium : 403 avec message du serveur', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Les classements sont reserves aux comptes Premium.',
        }, 403),
      );
      await expectLater(
        RankingRepository(api).users(RankingKind.sellers),
        throwsA(
          isA<ApiError>().having(
            (e) => e.userMessage,
            'message',
            'Les classements sont reserves aux comptes Premium.',
          ),
        ),
      );
    });
  });

  group('Modèles de classement', () {
    test('entrée utilisateur : mesures séparées de l\'identité', () {
      final e = RankingEntry.fromJson(<String, dynamic>{
        'rank': 2,
        'anonymous': true,
        'username': null,
        'full_name': 'Utilisateur anonyme',
        'avatar_url': null,
        'badges': <Object?>[],
        'score': 90,
        'total_views': 70,
        'total_likes': 20,
        'products_count': 4,
      });
      expect(e.anonymous, isTrue);
      expect(e.username, isNull);
      expect(e.metricInt('score'), 90);
      expect(e.metricInt('absent'), 0);
    });

    test('préférences de classement et résultat de candidature', () {
      expect(RankingPreferences.fromJson(null).isPremium, isFalse);
      final r = OfferApplyResult.fromJson(<String, dynamic>{
        'my_status': 'granted',
      });
      expect(r.myStatus, 'granted');
      expect(r.message, isNull);
    });
  });
}

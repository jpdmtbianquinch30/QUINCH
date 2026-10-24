import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/auth_repository.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';
import 'package:quinch_mobile/data/repositories/profile_repository.dart';
import 'package:quinch_mobile/data/repositories/safety_repository.dart';

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

  RequestOptions last() => adapter.requests.single;

  group('ProfileRepository', () {
    test('myProfile : lit le modèle utilisateur complet', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{
            'id': 'u1',
            'full_name': 'Awa',
            'city': 'Dakar',
            'bio': 'Bonjour',
          },
          'stats': <String, dynamic>{'products_count': 2},
        }, 200),
      );
      final user = await ProfileRepository(api).myProfile();
      expect(last().uri.path, '/api/v1/user/profile');
      expect(user.city, 'Dakar');
      expect(user.bio, 'Bonjour');
    });

    test('updateProfile : seuls les champs fournis sont envoyés', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{'id': 'u1', 'full_name': 'Awa Sow'},
        }, 200),
      );
      final user = await ProfileRepository(
        api,
      ).updateProfile(fullName: 'Awa Sow', bio: 'Salut');
      expect(last().method, 'PUT');
      expect(last().uri.path, '/api/v1/user/profile');
      expect(last().data, <String, Object?>{
        'full_name': 'Awa Sow',
        'bio': 'Salut',
      });
      expect(user.fullName, 'Awa Sow');
    });

    test(
      'updateProfile : changement d\'email avec mot de passe actuel',
      () async {
        build(
          (o) async => jsonResponse(<String, dynamic>{
            'user': <String, dynamic>{'id': 'u1'},
          }, 200),
        );
        await ProfileRepository(api).updateProfile(
          email: 'nouveau@example.sn',
          currentPassword: 'Secret123',
        );
        expect(last().data, <String, Object?>{
          'email': 'nouveau@example.sn',
          'current_password': 'Secret123',
        });
      },
    );

    test('updatePhone : numéro ou null pour supprimer', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{
            'id': 'u1',
            'phone_number': '+221771234567',
          },
        }, 200),
      );
      final user = await ProfileRepository(api).updatePhone('+221771234567');
      expect(last().uri.path, '/api/v1/user/phone');
      expect(last().data, <String, Object?>{'phone_number': '+221771234567'});
      expect(user.phoneNumber, '+221771234567');

      build(
        (o) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{'id': 'u1'},
        }, 200),
      );
      await ProfileRepository(api).updatePhone(null);
      expect(last().data, <String, Object?>{'phone_number': null});
    });

    test('profil public et annonces du vendeur', () async {
      build(
        (o) async => o.uri.path.endsWith('/products')
            ? jsonResponse(<String, dynamic>{
                'data': <Object?>[
                  <String, dynamic>{
                    'id': 'p',
                    'slug': 's',
                    'title': 'T',
                    'price': 100,
                  },
                ],
                'current_page': 1,
                'last_page': 2,
              }, 200)
            : jsonResponse(<String, dynamic>{
                'user': <String, dynamic>{
                  'id': 'v1',
                  'username': 'fatou',
                  'full_name': 'Fatou',
                },
                'stats': <String, dynamic>{'products_count': 4},
                'is_following': true,
              }, 200),
      );
      final repo = ProfileRepository(api);
      final profile = await repo.publicProfile('fatou');
      expect(adapter.requests.last.uri.path, '/api/v1/users/fatou/profile');
      expect(profile.isFollowing, isTrue);

      final page = await repo.sellerProducts('fatou', page: 2);
      expect(adapter.requests.last.uri.path, '/api/v1/users/fatou/products');
      expect(adapter.requests.last.uri.queryParameters, <String, dynamic>{
        'page': '2',
      });
      expect(page.hasMore, isTrue);
    });

    test('abonnement et désabonnement', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'following': true,
          'is_mutual': true,
          'message': 'Vous êtes maintenant amis!',
        }, 200),
      );
      final followed = await ProfileRepository(api).follow('v1');
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/follow/v1');
      expect(followed.following, isTrue);
      expect(followed.isMutual, isTrue);

      build(
        (o) async => jsonResponse(<String, dynamic>{
          'following': false,
          'message': 'Désabonnement réussi.',
        }, 200),
      );
      final unfollowed = await ProfileRepository(api).unfollow('v1');
      expect(last().method, 'DELETE');
      expect(last().uri.path, '/api/v1/unfollow/v1');
      expect(unfollowed.following, isFalse);
    });
  });

  group('SafetyRepository', () {
    test(
      'signaler une annonce : motif du serveur et description nettoyée',
      () async {
        build(
          (o) async => jsonResponse(<String, dynamic>{
            'message': 'Signalement envoyé. Merci pour votre vigilance.',
          }, 200),
        );
        final message = await SafetyRepository(api).reportProduct(
          'p1',
          ProductReportReason.counterfeit,
          description: '  fausse marque ',
        );
        expect(last().uri.path, '/api/v1/products/p1/report');
        expect(last().data, <String, Object?>{
          'reason': 'counterfeit',
          'description': 'fausse marque',
        });
        expect(message, 'Signalement envoyé. Merci pour votre vigilance.');
      },
    );

    test('signaler une annonce sans description : champ omis', () async {
      build((o) async => jsonResponse(<String, dynamic>{'message': 'ok'}, 200));
      await SafetyRepository(
        api,
      ).reportProduct('p1', ProductReportReason.spam, description: '   ');
      expect(last().data, <String, Object?>{'reason': 'spam'});
    });

    test('signaler un utilisateur', () async {
      build((o) async => jsonResponse(<String, dynamic>{'message': 'ok'}, 200));
      await SafetyRepository(
        api,
      ).reportUser('u9', UserReportReason.inappropriateContent);
      expect(last().uri.path, '/api/v1/users/u9/report');
      expect(last().data, <String, Object?>{'reason': 'inappropriate_content'});
    });

    test('valeurs de motifs : exactement celles acceptées par le backend', () {
      expect(ProductReportReason.values.map((r) => r.value), <String>[
        'fraud',
        'inappropriate',
        'counterfeit',
        'spam',
        'other',
      ]);
      expect(UserReportReason.values.map((r) => r.value), <String>[
        'harassment',
        'spam',
        'inappropriate_content',
        'fraud',
        'impersonation',
        'other',
      ]);
      expect(SupportCategory.values.map((c) => c.value), <String>[
        'bug',
        'suggestion',
        'security',
        'other',
      ]);
    });

    test('support', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Signalement reçu. Merci pour votre retour.',
        }, 200),
      );
      await SafetyRepository(
        api,
      ).reportProblem(SupportCategory.suggestion, '  Ajouter le mode sombre ');
      expect(last().uri.path, '/api/v1/support/report');
      expect(last().data, <String, Object?>{
        'category': 'suggestion',
        'description': 'Ajouter le mode sombre',
      });
    });

    test('blocage, déblocage et liste (réponse = tableau JSON)', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Utilisateur bloqué.',
        }, 200),
      );
      await SafetyRepository(api).blockUser('u9');
      expect(last().uri.path, '/api/v1/users/u9/block');

      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Utilisateur débloqué.',
        }, 200),
      );
      await SafetyRepository(api).unblockUser('u9');
      expect(last().uri.path, '/api/v1/users/u9/unblock');

      build(
        (o) async => jsonResponse(<Object?>[
          <String, dynamic>{
            'id': 'u9',
            'full_name': 'Moussa',
            'avatar_url': null,
            'blocked_at': '2026-10-01',
          },
        ], 200),
      );
      final list = await SafetyRepository(api).blockedUsers();
      expect(list.single.fullName, 'Moussa');
    });
  });

  group('AuthRepository (mot de passe, compte)', () {
    test('changement de mot de passe', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Mot de passe modifié avec succès.',
        }, 200),
      );
      final message = await AuthRepository(api).changePassword(
        currentPassword: 'Ancien123',
        newPassword: 'Nouveau123',
        confirmation: 'Nouveau123',
      );
      expect(last().method, 'PUT');
      expect(last().uri.path, '/api/v1/auth/change-password');
      expect(last().data, <String, Object?>{
        'current_password': 'Ancien123',
        'new_password': 'Nouveau123',
        'new_password_confirmation': 'Nouveau123',
      });
      expect(message, 'Mot de passe modifié avec succès.');
    });

    test('suppression du compte : mot de passe exigé', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Compte supprimé avec succès.',
        }, 200),
      );
      await AuthRepository(api).deleteAccount('Secret123');
      expect(last().method, 'POST');
      expect(last().uri.path, '/api/v1/auth/delete-account');
      expect(last().data, <String, Object?>{'password': 'Secret123'});
    });
  });

  group('ProductRepository (mes annonces)', () {
    test('liste paginée et suppression', () async {
      build(
        (o) async => o.method == 'DELETE'
            ? jsonResponse(<String, dynamic>{
                'message': 'Produit supprimé.',
              }, 200)
            : jsonResponse(<String, dynamic>{
                'data': <Object?>[
                  <String, dynamic>{
                    'id': 'p1',
                    'slug': 's',
                    'title': 'T',
                    'price': 100,
                    'status': 'draft',
                  },
                ],
                'current_page': 1,
                'last_page': 1,
              }, 200),
      );
      final repo = ProductRepository(api);
      final page = await repo.myProducts();
      expect(adapter.requests.last.uri.path, '/api/v1/my-products');
      expect(page.items.single.status, 'draft');

      await repo.deleteProduct('p1');
      expect(adapter.requests.last.method, 'DELETE');
      expect(adapter.requests.last.uri.path, '/api/v1/products/p1');
    });
  });
}

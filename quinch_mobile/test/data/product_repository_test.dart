import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/repositories/favorites_repository.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';

import '../support/fakes.dart';

// Ces tests vérifient les paramètres ENVOYÉS et la lecture de réponses simulées
// d'après le code du backend. Ils ne prouvent pas le comportement d'un vrai serveur.

void main() {
  late FakeAdapter adapter;
  late ProductRepository repo;
  late FavoritesRepository favorites;

  void build(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = FakeAdapter(handler);
    final config = AppConfig.parse(
      'https://api.quinch.sn/api/v1',
      allowInsecure: false,
    );
    final api = ApiClient(
      dio: createDio(
        config: config,
        tokens: AuthTokenHolder(),
        adapter: adapter,
      ),
      tokens: AuthTokenHolder(),
    );
    repo = ProductRepository(api);
    favorites = FavoritesRepository(api);
  }

  Map<String, dynamic> query() => adapter.requests.single.uri.queryParameters;

  group('feed', () {
    test('paramètres : page, per_page, tab', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'data': <Object?>[],
          'current_page': 1,
          'last_page': 1,
        }, 200),
      );
      await repo.feed(page: 2, tab: FeedTab.following);
      expect(adapter.requests.single.uri.path, '/api/v1/products/feed');
      expect(query(), <String, dynamic>{
        'page': '2',
        'per_page': '10',
        'tab': 'following',
      });
    });

    test('lecture d\'une page', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'data': <Object?>[
            <String, dynamic>{
              'id': 'p1',
              'slug': 's',
              'title': 'T',
              'price': 100,
            },
          ],
          'current_page': 1,
          'last_page': 3,
          'total': 25,
        }, 200),
      );
      final page = await repo.feed();
      expect(page.items.single.title, 'T');
      expect(page.hasMore, isTrue);
    });
  });

  group('explorer', () {
    test(
      'noms de paramètres LUS dans le backend : price_min, price_max, sort_by',
      () async {
        build(
          (o) async =>
              jsonResponse(<String, dynamic>{'data': <Object?>[]}, 200),
        );
        await repo.explore(
          categoryId: 'c1',
          type: 'service',
          priceMin: 1000,
          priceMax: 5000,
          sort: ExploreSort.priceAsc,
        );
        final q = query();
        expect(q['price_min'], '1000');
        expect(q['price_max'], '5000');
        expect(q['sort_by'], 'price_asc');
        expect(q['category'], 'c1');
        expect(q['type'], 'service');
        // Noms propres au feed ou à Angular, ignorés par l'Explorer.
        expect(q.containsKey('min_price'), isFalse);
        expect(q.containsKey('max_price'), isFalse);
        expect(q.containsKey('condition'), isFalse);
      },
    );

    test('sans filtre : seulement la pagination', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{'data': <Object?>[]}, 200),
      );
      await repo.explore();
      expect(query(), <String, dynamic>{'page': '1', 'per_page': '20'});
    });

    test(
      'catégorie sous forme de texte et objet : lecture tolérante',
      () async {
        build(
          (o) async => jsonResponse(<String, dynamic>{
            'data': <Object?>[
              <String, dynamic>{
                'id': 'p',
                'slug': 's',
                'title': 'T',
                'price': 1,
                'category': 'Mode',
                'category_id': 'c1',
              },
            ],
            'current_page': 1,
            'last_page': 1,
          }, 200),
        );
        final page = await repo.explore();
        expect(page.items.single.categoryName, 'Mode');
      },
    );
  });

  group('recherche, détail, catégories', () {
    test('recherche : texte nettoyé, résultats typés', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'products': <Object?>[
            <String, dynamic>{
              'id': 'p',
              'slug': 's',
              'title': 'T',
              'price': 10,
              'seller': 'fatou',
              'seller_id': 'u1',
            },
          ],
          'users': <Object?>[
            <String, dynamic>{
              'id': 'u1',
              'full_name': 'Fatou',
              'username': 'fatou',
            },
          ],
        }, 200),
      );
      final results = await repo.search('  robe ');
      expect(query(), <String, dynamic>{'q': 'robe'});
      expect(results.products.single.sellerUsername, 'fatou');
      expect(results.users.single.fullName, 'Fatou');
    });

    test('détail par slug', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'product': <String, dynamic>{
            'id': 'p',
            'slug': 'robe-wax',
            'title': 'Robe',
            'price': 10,
          },
          'seller': <String, dynamic>{'id': 's', 'full_name': 'Fatou'},
          'is_liked': true,
          'is_saved': false,
        }, 200),
      );
      final detail = await repo.detail('robe-wax');
      expect(adapter.requests.single.uri.path, '/api/v1/products/robe-wax');
      expect(detail.product.isLiked, isTrue);
    });

    test('catégories', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'categories': <Object?>[
            <String, dynamic>{
              'id': 'c1',
              'name': 'Mode',
              'children': <Object?>[
                <String, dynamic>{'id': 'c2', 'name': 'Robes'},
              ],
            },
          ],
        }, 200),
      );
      final list = await repo.categories();
      expect(list.single.children.single.name, 'Robes');
    });
  });

  group('actions', () {
    test('like : POST et lecture de la réponse', () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'liked': true,
          'like_count': 7,
        }, 200),
      );
      final result = await repo.like('p1');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/v1/products/p1/like');
      expect(result.liked, isTrue);
      expect(result.likeCount, 7);
    });

    test('enregistrer : renvoie l\'état réel du serveur', () async {
      build((o) async => jsonResponse(<String, dynamic>{'saved': false}, 200));
      expect(await repo.toggleSave('p1'), isFalse);
      expect(adapter.requests.single.uri.path, '/api/v1/products/p1/save');
    });
  });

  test(
    'favoris : paginateur de FavoriteItem, annonce supprimée tolérée',
    () async {
      build(
        (o) async => jsonResponse(<String, dynamic>{
          'data': <Object?>[
            <String, dynamic>{
              'id': 'f1',
              'product_id': 'p1',
              'price_at_save': 1000,
              'product': <String, dynamic>{
                'id': 'p1',
                'slug': 's',
                'title': 'T',
                'price': 1200,
              },
            },
            <String, dynamic>{'id': 'f2', 'product_id': 'p2', 'product': null},
          ],
          'current_page': 1,
          'last_page': 1,
        }, 200),
      );
      final page = await favorites.list(page: 1);
      expect(adapter.requests.single.uri.path, '/api/v1/favorites');
      expect(page.items.first.product?.title, 'T');
      expect(page.items.first.priceAtSave, 1000);
      expect(page.items.last.product, isNull);
    },
  );
}

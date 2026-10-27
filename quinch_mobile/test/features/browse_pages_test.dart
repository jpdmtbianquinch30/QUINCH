import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/format/fcfa.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/providers.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';
import 'package:quinch_mobile/features/explore/explore_page.dart';
import 'package:quinch_mobile/features/favorites/favorites_page.dart';
import 'package:quinch_mobile/features/chat/chat_providers.dart';
import 'package:quinch_mobile/features/feed/feed_page.dart';
import 'package:quinch_mobile/features/notifications/notification_providers.dart';
import 'package:quinch_mobile/features/product/product_detail_page.dart';
import 'package:quinch_mobile/features/product/product_providers.dart';
import 'package:quinch_mobile/features/search/search_page.dart';

import '../support/fakes.dart';

/// Monte une page dans un routeur minimal ; les écrans voisins sont des textes repères.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  FakeProductRepository? products,
  FakeFavoritesRepository? favorites,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => page),
      GoRoute(
        path: '/product/:slug',
        builder: (context, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['slug']}')),
      ),
      GoRoute(
        path: searchPath,
        builder: (context, state) =>
            const Scaffold(body: Text('ÉCRAN RECHERCHE')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse('https://api.quinch.sn/api/v1', allowInsecure: false),
        ),
        productRepositoryProvider.overrideWithValue(
          products ?? FakeProductRepository(),
        ),
        favoritesRepositoryProvider.overrideWithValue(
          favorites ?? FakeFavoritesRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FeedPage', () {
    testWidgets('affiche les annonces avec leur prix en FCFA', (tester) async {
      final products = FakeProductRepository()
        ..onFeed = (page, tab) async =>
            pageOf<ProductCard>(<ProductCard>[sampleCard(title: 'Robe wax')]);
      await pumpPage(tester, const FeedPage(), products: products);

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text(formatFcfa(15000)), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
    });

    testWidgets('onglet Abonnements : charge le fil des abonnements', (
      tester,
    ) async {
      final products = FakeProductRepository();
      await pumpPage(tester, const FeedPage(), products: products);
      expect(products.feedTabs, <FeedTab>[FeedTab.forYou]);

      await tester.tap(find.text('Abonnements'));
      await tester.pumpAndSettle();
      expect(products.feedTabs, <FeedTab>[FeedTab.forYou, FeedTab.following]);
      expect(find.textContaining('Abonnez-vous'), findsOneWidget);
    });

    testWidgets(
      '« j\'aime » : compteur mis à jour avec la réponse du serveur',
      (tester) async {
        final products = FakeProductRepository()
          ..onFeed = (page, tab) async =>
              pageOf<ProductCard>(<ProductCard>[sampleCard(likes: 4)]);
        await pumpPage(tester, const FeedPage(), products: products);
        expect(find.text('4'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pumpAndSettle();

        expect(find.text('5'), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
      },
    );

    testWidgets('« j\'aime » refusé : message affiché, compteur inchangé', (
      tester,
    ) async {
      final products = FakeProductRepository();
      products.onFeed = (page, tab) async =>
          pageOf<ProductCard>(<ProductCard>[sampleCard(likes: 4)]);
      products.onLike = (id) async => throw ApiError.network();
      await pumpPage(tester, const FeedPage(), products: products);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('erreur au chargement puis réessai', (tester) async {
      final products = FakeProductRepository()
        ..onFeed = (page, tab) async => throw ApiError.network();
      await pumpPage(tester, const FeedPage(), products: products);
      expect(
        find.text('Connexion impossible. Vérifiez votre réseau.'),
        findsOneWidget,
      );

      products.onFeed = (page, tab) async =>
          pageOf<ProductCard>(<ProductCard>[sampleCard(title: 'Sac cuir')]);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Sac cuir'), findsOneWidget);
    });

    testWidgets('aucune annonce', (tester) async {
      await pumpPage(tester, const FeedPage());
      expect(find.text('Aucune annonce vidéo pour le moment.'), findsOneWidget);
    });
  });

  group('ExplorePage', () {
    testWidgets('grille d\'annonces, produit et service distingués', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onExplore = (page) async => pageOf<ProductCard>(<ProductCard>[
          sampleCard(id: 'a', slug: 'a', title: 'Robe wax', price: 15000),
          sampleCard(
            id: 'b',
            slug: 'b',
            title: 'Coiffure',
            price: 8000,
            type: 'service',
          ),
        ]);
      await pumpPage(tester, const ExplorePage(), products: products);

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('Coiffure'), findsOneWidget);
      expect(find.text('Produit'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
    });

    testWidgets('filtre « Services » : nouvelle requête avec type=service', (
      tester,
    ) async {
      final products = FakeProductRepository();
      await pumpPage(tester, const ExplorePage(), products: products);
      expect(products.exploreCalls.single['type'], isNull);

      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      expect(products.exploreCalls.last['type'], 'service');
      expect(products.exploreCalls.last['page'], 1);
      expect(
        find.text('Aucune annonce ne correspond à ces filtres.'),
        findsOneWidget,
      );
    });

    testWidgets('toucher une annonce ouvre son détail', (tester) async {
      final products = FakeProductRepository()
        ..onExplore = (page) async =>
            pageOf<ProductCard>(<ProductCard>[sampleCard(slug: 'robe-wax')]);
      await pumpPage(tester, const ExplorePage(), products: products);

      await tester.tap(find.text('Robe wax'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL robe-wax'), findsOneWidget);
    });

    testWidgets('l\'icône de recherche ouvre la recherche', (tester) async {
      await pumpPage(tester, const ExplorePage());
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('ÉCRAN RECHERCHE'), findsOneWidget);
    });
  });

  group('SearchPage', () {
    testWidgets('invite à saisir 2 caractères, puis affiche les résultats', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onSearch = (q) async => SearchResults.fromJson(<String, dynamic>{
          'products': <Object?>[
            <String, dynamic>{
              'id': 'p',
              'slug': 'robe',
              'title': 'Robe wax',
              'price': 15000,
              'seller': 'fatou',
            },
          ],
          'users': <Object?>[],
        });
      await pumpPage(tester, const SearchPage(), products: products);
      expect(find.textContaining('au moins 2 caractères'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'robe');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.textContaining('@fatou'), findsOneWidget);
    });

    testWidgets('aucun résultat', (tester) async {
      await pumpPage(tester, const SearchPage());
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Aucune annonce trouvée.'), findsOneWidget);
    });
  });

  group('ProductDetailPage', () {
    testWidgets('affiche les informations de l\'annonce et du vendeur', (
      tester,
    ) async {
      final products = FakeProductRepository();
      await pumpPage(
        tester,
        const ProductDetailPage(slug: 'robe-wax'),
        products: products,
      );

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text(formatFcfa(15000)), findsOneWidget);
      expect(find.text('Neuf'), findsOneWidget);
      expect(find.text('Prix négociable'), findsOneWidget);
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Livraison : ${formatFcfa(1500)}'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('@fatou'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
    });

    testWidgets('une vue est comptée une seule fois', (tester) async {
      final products = FakeProductRepository();
      await pumpPage(
        tester,
        const ProductDetailPage(slug: 'robe-wax'),
        products: products,
      );
      expect(products.viewed, <String>['p1']);
    });

    testWidgets('annonce introuvable : message du serveur', (tester) async {
      final products = FakeProductRepository()
        ..onDetail = (slug) async => throw ApiError.fromResponse(
          404,
          <String, dynamic>{'message': 'Annonce introuvable.'},
        );
      await pumpPage(
        tester,
        const ProductDetailPage(slug: 'inconnu'),
        products: products,
      );
      expect(find.text('Annonce introuvable.'), findsOneWidget);
    });

    testWidgets('annonce vendue : statut affiché', (tester) async {
      expect(statusLabel('sold'), 'Vendu');
      expect(statusLabel('reserved'), 'Réservé');
      expect(statusLabel('active'), '');
      expect(conditionLabel('like_new'), 'Comme neuf');
      expect(conditionLabel(null), '');
    });

    testWidgets('enregistrer : l\'icône reflète la réponse du serveur', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onToggleSave = (id) async => true;
      await pumpPage(
        tester,
        const ProductDetailPage(slug: 'robe-wax'),
        products: products,
      );

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });
  });

  group('FavoritesPage', () {
    testWidgets('liste puis retrait d\'un favori', (tester) async {
      final favorites = FakeFavoritesRepository()
        ..onList = (page) async => pageOf<FavoriteEntry>(<FavoriteEntry>[
          sampleFavorite(sampleCard(title: 'Robe wax')),
        ]);
      final products = FakeProductRepository()
        ..onToggleSave = (id) async => false;
      await pumpPage(
        tester,
        const FavoritesPage(),
        products: products,
        favorites: favorites,
      );
      expect(find.text('Robe wax'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      expect(find.text('Robe wax'), findsNothing);
      expect(find.text("Vous n'avez encore aucun favori."), findsOneWidget);
    });

    testWidgets('aucun favori', (tester) async {
      await pumpPage(tester, const FavoritesPage());
      expect(find.text("Vous n'avez encore aucun favori."), findsOneWidget);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/features/profile/my_products_page.dart';
import 'package:quinch_mobile/features/sell/listing_fee.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

Finder get menuButton => find.byTooltip("Actions sur l'annonce");

Future<void> openMenu(WidgetTester tester, {int index = 0}) async {
  await tester.tap(menuButton.at(index));
  await tester.pumpAndSettle();
}

void main() {
  group('Mes annonces — actions', () {
    late int loads;

    FakeProductRepository repoWith(List<ProductCard> cards) {
      loads = 0;
      return FakeProductRepository()
        ..onMyProducts = (page) async {
          loads++;
          return pageOf<ProductCard>(cards);
        };
    }

    ProductCard active() =>
        sampleCard(id: 'a', slug: 'a', title: 'Robe wax', status: 'active');
    ProductCard draft() =>
        sampleCard(id: 'b', slug: 'b', title: 'Sac cuir', status: 'draft');

    testWidgets('annonce en ligne : modifier, pause, réservé, vendu', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: repoWith([active(), draft()]),
      );

      await openMenu(tester);

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Mettre en pause'), findsOneWidget);
      expect(find.text('Marquer comme réservé'), findsOneWidget);
      expect(find.text('Marquer comme vendu'), findsOneWidget);
      expect(find.text('Publier cette annonce'), findsNothing);
    });

    testWidgets('brouillon : modifier et publier seulement', (tester) async {
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: repoWith([active(), draft()]),
      );

      await openMenu(tester, index: 1);

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Publier cette annonce'), findsOneWidget);
      expect(find.text('Mettre en pause'), findsNothing);
      expect(find.text('Remettre en ligne'), findsNothing);
    });

    testWidgets('annonce désactivée par la modération : aucune action', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: repoWith([
          sampleCard(id: 'd', slug: 'd', title: 'Bloquée', status: 'disabled'),
        ]),
      );

      expect(find.text('Désactivée'), findsOneWidget);
      expect(menuButton, findsNothing);
    });

    testWidgets('mettre en pause : statut envoyé puis liste rechargée', (
      tester,
    ) async {
      final products = repoWith([active(), draft()]);
      await pumpScreen(tester, const MyProductsPage(), products: products);
      final before = loads;

      await openMenu(tester);
      await tester.tap(find.text('Mettre en pause'));
      await tester.pumpAndSettle();

      final (id, update) = products.updated.single;
      expect(id, 'a');
      expect(update.toJson(), <String, Object>{'status': 'paused'});
      expect(find.text('Produit mis à jour.'), findsOneWidget);
      expect(loads, greaterThan(before));
    });

    testWidgets('statut refusé par le serveur : message affiché', (
      tester,
    ) async {
      final products = repoWith([active(), draft()])
        ..onUpdate = (id, update) async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'Changement de statut non autorisé.',
              'error': 'invalid_status_transition',
            });
      await pumpScreen(tester, const MyProductsPage(), products: products);

      await openMenu(tester);
      await tester.tap(find.text('Marquer comme vendu'));
      await tester.pumpAndSettle();

      expect(find.text('Changement de statut non autorisé.'), findsOneWidget);
    });

    testWidgets('modifier : ouvre l\'écran de modification', (tester) async {
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: repoWith([active(), draft()]),
      );

      await openMenu(tester);
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE /my-products/edit'), findsOneWidget);
    });

    testWidgets('publier un brouillon sans frais', (tester) async {
      final products = repoWith([active(), draft()]);
      await pumpScreen(tester, const MyProductsPage(), products: products);
      final before = loads;

      await openMenu(tester, index: 1);
      await tester.tap(find.text('Publier cette annonce'));
      await tester.pumpAndSettle();

      expect(products.published, <String>['b']);
      expect(find.text('Annonce publiée.'), findsOneWidget);
      expect(loads, greaterThan(before));
    });

    testWidgets('publier avec frais : paiement ouvert, rien de confirmé', (
      tester,
    ) async {
      final opened = <Uri>[];
      final products = repoWith([active(), draft()])
        ..onPublish = (id) async => ProductSaveResult(
          product: sampleCard(id: id, status: 'draft'),
          message: 'Paiement requis.',
          paymentUrl: 'https://pay.example/abc',
          fee: 150,
        );
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: products,
        openedUrls: opened,
      );

      await openMenu(tester, index: 1);
      await tester.tap(find.text('Publier cette annonce'));
      await tester.pumpAndSettle();
      expect(find.text('Frais de publication vidéo'), findsOneWidget);

      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://pay.example/abc')]);
      expect(find.text(listingFeePendingMessage), findsOneWidget);
    });

    testWidgets('publier avec frais : « Plus tard » n\'ouvre rien', (
      tester,
    ) async {
      final opened = <Uri>[];
      final products = repoWith([active(), draft()])
        ..onPublish = (id) async => ProductSaveResult(
          product: sampleCard(id: id, status: 'draft'),
          paymentUrl: 'https://pay.example/abc',
          fee: 150,
        );
      await pumpScreen(
        tester,
        const MyProductsPage(),
        products: products,
        openedUrls: opened,
      );

      await openMenu(tester, index: 1);
      await tester.tap(find.text('Publier cette annonce'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.text(listingFeeLaterMessage), findsOneWidget);
    });

    test('libellés des nouveaux statuts', () {
      expect(productStatusLabel('paused'), 'En pause');
      expect(productStatusLabel('expired'), 'Expirée');
      expect(productStatusLabel('disabled'), 'Désactivée');
    });
  });
}

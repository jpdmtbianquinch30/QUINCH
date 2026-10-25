import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/new_product.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/features/profile/edit_product_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

ProductCard product({String type = 'product'}) => sampleCard(
  id: 'p1',
  slug: 'robe-wax',
  title: 'Robe wax',
  price: 15000,
  type: type,
  status: 'active',
  description: 'Belle robe',
  stock: 3,
  condition: 'good',
  negotiable: true,
);

Finder get saveButton => find.widgetWithText(FilledButton, 'Enregistrer');

void main() {
  group('EditProductPage', () {
    testWidgets('champs préremplis avec l\'annonce', (tester) async {
      await pumpScreen(tester, EditProductPage(card: product()));

      expect(find.text('Robe wax'), findsOneWidget);
      expect(find.text('15000'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Belle robe'), findsOneWidget);
      expect(find.text('Bon état'), findsOneWidget);
    });

    testWidgets('seuls les champs modifiés sont envoyés', (tester) async {
      final env = await pumpScreen(tester, EditProductPage(card: product()));

      await tester.enterText(fieldByLabel('Titre'), '  Robe wax rouge ');
      await tester.enterText(fieldByLabel('Prix (FCFA)'), '18000');
      await tapVisible(tester, saveButton);

      final (id, update) = env.products.updated.single;
      expect(id, 'p1');
      expect(update.toJson(), <String, Object>{
        'title': 'Robe wax rouge',
        'price': 18000,
      });
      expect(find.text('Produit mis à jour.'), findsOneWidget);
    });

    testWidgets('état, stock et négociable modifiés', (tester) async {
      final env = await pumpScreen(tester, EditProductPage(card: product()));

      await tester.enterText(fieldByLabel('Quantité en stock'), '0');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<ProductCondition>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neuf').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, saveButton);

      expect(env.products.updated.single.$2.toJson(), <String, Object>{
        'stock_quantity': 0,
        'is_negotiable': false,
        'condition': 'new',
      });
    });

    testWidgets('aucune modification : rien n\'est envoyé', (tester) async {
      final env = await pumpScreen(tester, EditProductPage(card: product()));

      await tapVisible(tester, saveButton);

      expect(env.products.updated, isEmpty);
      expect(find.text('Aucune modification à enregistrer.'), findsOneWidget);
    });

    testWidgets('validation : titre, prix, description non vidés', (
      tester,
    ) async {
      final env = await pumpScreen(tester, EditProductPage(card: product()));

      await tester.enterText(fieldByLabel('Titre'), '');
      await tester.enterText(fieldByLabel('Prix (FCFA)'), 'abc');
      await tester.enterText(fieldByLabel('Description'), '');
      await tapVisible(tester, saveButton);

      expect(find.text('Saisissez le titre de votre annonce.'), findsOneWidget);
      expect(find.textContaining('Indiquez un prix en FCFA'), findsOneWidget);
      expect(
        find.text('La description ne peut pas être vide.'),
        findsOneWidget,
      );
      expect(env.products.updated, isEmpty);
    });

    testWidgets('service : ni stock ni état', (tester) async {
      await pumpScreen(tester, EditProductPage(card: product(type: 'service')));

      expect(find.text('Quantité en stock'), findsNothing);
      expect(find.text('État'), findsNothing);
      expect(find.text('Prix négociable'), findsOneWidget);
    });

    testWidgets('refus du serveur : message du champ, écran conservé', (
      tester,
    ) async {
      final products = FakeProductRepository()
        ..onUpdate = (id, update) async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'Les données sont invalides.',
              'errors': <String, dynamic>{
                'price': <String>['Le prix est invalide.'],
              },
            });
      await pumpScreen(
        tester,
        EditProductPage(card: product()),
        products: products,
      );

      await tester.enterText(fieldByLabel('Prix (FCFA)'), '18000');
      await tapVisible(tester, saveButton);

      expect(find.text('Le prix est invalide.'), findsWidgets);
      expect(find.text("Modifier l'annonce"), findsOneWidget);
    });
  });

  testWidgets('écran sans annonce : message clair', (tester) async {
    await pumpScreen(tester, const MissingProductPage());

    expect(find.textContaining("n'est plus disponible"), findsOneWidget);
  });
}

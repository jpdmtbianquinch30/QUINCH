import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/new_product.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';

import '../support/fakes.dart';

void main() {
  group('ProductUpdate', () {
    test('rien de renseigné : vide, aucun champ envoyé', () {
      const update = ProductUpdate();
      expect(update.isEmpty, isTrue);
      expect(update.toJson(), isEmpty);
    });

    test(
      'seuls les champs renseignés sont envoyés, avec les noms du serveur',
      () {
        const update = ProductUpdate(
          title: 'Robe',
          description: 'Belle',
          price: 18000,
          stockQuantity: 0,
          condition: ProductCondition.likeNew,
          isNegotiable: false,
          status: 'paused',
        );

        expect(update.isEmpty, isFalse);
        expect(update.toJson(), <String, Object>{
          'title': 'Robe',
          'description': 'Belle',
          'price': 18000,
          'stock_quantity': 0,
          'condition': 'like_new',
          'is_negotiable': false,
          'status': 'paused',
        });
        expect(const ProductUpdate(price: 5).toJson(), <String, Object>{
          'price': 5,
        });
      },
    );
  });

  group('ProductRepository — publication et modification', () {
    ProductRepository repoFor(FakeAdapter adapter) {
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      return ProductRepository(
        ApiClient(
          dio: createDio(config: config, tokens: tokens, adapter: adapter),
          tokens: tokens,
        ),
      );
    }

    Map<String, dynamic> productJson(String status) => <String, dynamic>{
      'id': 'p1',
      'slug': 'robe-wax',
      'title': 'Robe wax',
      'price': 15000,
      'status': status,
    };

    test('publish : POST products/{id}/publish, annonce en ligne', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Annonce publiée.',
          'product': productJson('active'),
        }, 200),
      );

      final result = await repoFor(adapter).publishProduct('p1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/products/p1/publish');
      expect(result.product.status, 'active');
      expect(result.message, 'Annonce publiée.');
      expect(result.paymentUrl, isNull);
    });

    test(
      'publish : frais dus, brouillon et adresse de paiement du serveur',
      () async {
        final adapter = FakeAdapter(
          (o) async => jsonResponse(<String, dynamic>{
            'message': 'Paiement requis.',
            'product': productJson('draft'),
            'payment_url': 'https://pay.example/abc',
            'fee': 150,
          }, 200),
        );

        final result = await repoFor(adapter).publishProduct('p1');

        expect(result.product.status, 'draft');
        expect(result.paymentUrl, 'https://pay.example/abc');
        expect(result.fee, 150);
      },
    );

    test('update : PUT products/{id} avec les seuls champs modifiés', () async {
      final adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Produit mis à jour.',
          'product': productJson('paused'),
        }, 200),
      );

      final result = await repoFor(adapter).updateProduct(
        'p1',
        const ProductUpdate(price: 18000, status: 'paused'),
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri.path, '/api/v1/products/p1');
      expect(request.data, <String, Object>{
        'price': 18000,
        'status': 'paused',
      });
      expect(result.product.status, 'paused');
      expect(result.message, 'Produit mis à jour.');
    });
  });
}

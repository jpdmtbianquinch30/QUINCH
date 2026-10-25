import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/network/api_client.dart';
import 'package:quinch_mobile/core/network/auth_token_holder.dart';
import 'package:quinch_mobile/core/network/dio_factory.dart';
import 'package:quinch_mobile/data/models/new_product.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';

import '../support/fakes.dart';

const mb = 1024 * 1024;

PickedImage image(String name, int size) =>
    PickedImage(path: '/tmp/$name', name: name, sizeBytes: size);

void main() {
  group('validateListingImage', () {
    test('formats et taille', () {
      expect(validateListingImage(image('a.jpg', 1000)), isNull);
      expect(validateListingImage(image('a.PNG', 5 * mb)), isNull);
      expect(validateListingImage(image('a.webp', 1000)), isNull);
      expect(validateListingImage(image('photo', 1000)), isNull);
      expect(
        validateListingImage(image('a.jpg', 5 * mb + 1)),
        contains('5 Mo'),
      );
      expect(
        validateListingImage(image('a.gif', 1000)),
        contains('JPEG, PNG ou WebP'),
      );
      expect(validateListingImage(image('a.jpg', 0)), contains('vide'));
    });
  });

  group('ProductRepository.createProduct', () {
    late FakeAdapter adapter;
    late ApiClient api;
    late Directory tmp;
    late PickedImage poster;
    late PickedImage extra1;
    late PickedImage extra2;

    Future<PickedImage> makeImage(String name) async {
      final file = File('${tmp.path}/$name');
      await file.writeAsBytes(<int>[1, 2, 3]);
      return PickedImage(path: file.path, name: name, sizeBytes: 3);
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('quinch_sell_');
      poster = await makeImage('cover.jpg');
      extra1 = await makeImage('a.png');
      extra2 = await makeImage('b.webp');

      adapter = FakeAdapter(
        (o) async => jsonResponse(<String, dynamic>{
          'message': 'Brouillon enregistré.',
          'payment_url': 'https://pay.example/abc',
          'fee': 150,
          'product': <String, dynamic>{
            'id': 'p9',
            'slug': 'robe-wax',
            'title': 'Robe wax',
            'price': 15000,
          },
        }, 201),
      );
      final config = AppConfig.parse(
        'https://api.quinch.sn/api/v1',
        allowInsecure: false,
      );
      final tokens = AuthTokenHolder();
      api = ApiClient(
        dio: createDio(config: config, tokens: tokens, adapter: adapter),
        tokens: tokens,
      );
    });

    tearDown(() async {
      // Voir profile_images_test : sous Windows le fichier peut rester verrouillé.
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // dossier temporaire : nettoyé par le système
      }
    });

    test('POST products : champs, fichiers et résultat du serveur', () async {
      final result = await ProductRepository(api).createProduct(
        NewProduct(
          title: 'Robe wax',
          categoryId: 'c1',
          price: 15000,
          poster: poster,
          description: 'Très belle robe',
          condition: ProductCondition.likeNew,
          isNegotiable: false,
          images: <PickedImage>[extra1, extra2],
        ),
        PublishIntent.draft,
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/products');
      final form = request.data as FormData;
      final fields = <String, String>{
        for (final e in form.fields) e.key: e.value,
      };
      expect(fields['title'], 'Robe wax');
      expect(fields['category_id'], 'c1');
      expect(fields['price'], '15000');
      expect(fields['type'], 'product');
      expect(fields['condition'], 'like_new');
      expect(fields['is_negotiable'], '0');
      expect(fields['stock_quantity'], '1');
      expect(fields['description'], 'Très belle robe');
      expect(fields['intent'], 'draft');
      expect(form.files.map((e) => e.key).toList(), <String>[
        'poster_file',
        'image_files[]',
        'image_files[]',
      ]);
      expect(form.files.map((e) => e.value.filename).toList(), <String?>[
        'cover.jpg',
        'a.png',
        'b.webp',
      ]);
      expect(result.product.id, 'p9');
      expect(result.message, 'Brouillon enregistré.');
      expect(result.paymentUrl, 'https://pay.example/abc');
      expect(result.fee, 150);
    });

    test('sans description : le champ n\'est pas envoyé', () async {
      await ProductRepository(api).createProduct(
        NewProduct(
          title: 'Robe',
          categoryId: 'c1',
          price: 1000,
          poster: poster,
        ),
        PublishIntent.publish,
      );

      final form = adapter.requests.single.data as FormData;
      final keys = form.fields.map((e) => e.key).toList();
      expect(keys, isNot(contains('description')));
      expect(form.fields.firstWhere((e) => e.key == 'intent').value, 'publish');
      expect(form.files, hasLength(1));
    });
  });
}

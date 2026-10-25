import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/media/picked_video.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/platform/image_picker.dart';
import 'package:quinch_mobile/data/models/new_product.dart';
import 'package:quinch_mobile/data/models/premium.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/features/profile/my_products_page.dart';
import 'package:quinch_mobile/features/sell/listing_fee.dart';
import 'package:quinch_mobile/features/sell/sell_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

const mb = 1024 * 1024;

PickedImage image(String name, [int size = 1000]) =>
    PickedImage(path: '/tmp/$name', name: name, sizeBytes: size);

FakeProductRepository productsWithCategory() => FakeProductRepository()
  ..onCategories = () async => const <Category>[
    Category(id: 'c1', name: 'Mode'),
    Category(id: 'c2', name: 'Maison'),
  ];

/// Écran assez haut pour que tout le formulaire soit construit.
Future<ScreenEnv> pumpSell(
  WidgetTester tester, {
  FakeProductRepository? products,
  ImagePick? pickImage,
  ImagesPick? pickImages,
  VideoPick? pickVideo,
  FakePremiumRepository? premium,
  List<Uri>? openedUrls,
}) async {
  final env = await pumpScreen(
    tester,
    const SellPage(),
    products: products ?? productsWithCategory(),
    pickImage: pickImage ?? () async => image('cover.jpg'),
    pickImages: pickImages,
    pickVideo: pickVideo,
    premium: premium,
    openedUrls: openedUrls,
  );
  tester.view.physicalSize = const Size(400, 2200);
  await tester.pumpAndSettle();
  return env;
}

Finder get publishButton => find.widgetWithText(FilledButton, 'Publier');
Finder get draftButton =>
    find.widgetWithText(OutlinedButton, 'Enregistrer en brouillon');

Future<void> chooseCategory(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> fillValidForm(WidgetTester tester) async {
  await tapVisible(tester, find.text('Choisir la couverture'));
  await tester.enterText(fieldByLabel('Titre'), '  Robe wax  ');
  await chooseCategory(tester, 'Mode');
  await tester.enterText(fieldByLabel('Prix (FCFA)'), '15000');
  await tester.enterText(fieldByLabel('Description'), 'Très belle robe');
}

void main() {
  group('SellPage', () {
    testWidgets('champs obligatoires : messages et aucun envoi', (
      tester,
    ) async {
      final env = await pumpSell(tester);

      await tapVisible(tester, publishButton);

      expect(find.text('Saisissez le titre de votre annonce.'), findsOneWidget);
      expect(find.text('Choisissez une catégorie.'), findsOneWidget);
      expect(
        find.text('Ajoutez au moins une photo ou une vidéo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Indiquez un prix en FCFA'), findsOneWidget);
      expect(env.products.created, isEmpty);
    });

    testWidgets('publication : champs envoyés puis retour à Mes annonces', (
      tester,
    ) async {
      final env = await pumpSell(
        tester,
        pickImages: () async => [image('a.jpg'), image('b.png')],
      );
      await fillValidForm(tester);
      await tapVisible(tester, find.text('Ajouter des photos'));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tapVisible(tester, publishButton);

      expect(env.products.created, hasLength(1));
      final (product, intent) = env.products.created.single;
      expect(intent, PublishIntent.publish);
      expect(product.title, 'Robe wax');
      expect(product.categoryId, 'c1');
      expect(product.price, 15000);
      expect(product.description, 'Très belle robe');
      expect(product.condition, ProductCondition.brandNew);
      expect(product.isNegotiable, isFalse);
      expect(product.poster?.name, 'cover.jpg');
      expect(product.images.map((i) => i.name).toList(), ['a.jpg', 'b.png']);
      expect(find.text('ROUTE /my-products'), findsOneWidget);
    });

    testWidgets('brouillon : intent « draft »', (tester) async {
      final env = await pumpSell(tester);
      await fillValidForm(tester);

      await tapVisible(tester, draftButton);

      expect(env.products.created.single.$2, PublishIntent.draft);
      expect(find.text('ROUTE /my-products'), findsOneWidget);
    });

    testWidgets('couverture de plus de 5 Mo : refusée', (tester) async {
      await pumpSell(tester, pickImage: () async => image('gros.jpg', 6 * mb));

      await tapVisible(tester, find.text('Choisir la couverture'));

      expect(find.textContaining('dépasse 5 Mo'), findsOneWidget);
      expect(find.text('Choisir la couverture'), findsOneWidget);
    });

    testWidgets('photos : doublons ignorés, 10 supplémentaires au maximum', (
      tester,
    ) async {
      await pumpSell(
        tester,
        pickImages: () async => [
          for (var i = 0; i < 12; i++) image('p$i.jpg'),
          image('p0.jpg'),
        ],
      );

      await tapVisible(tester, find.text('Ajouter des photos'));

      expect(find.text('Ajouter des photos (10)'), findsOneWidget);
      expect(find.text('10 photos supplémentaires maximum.'), findsOneWidget);
    });

    testWidgets('retirer une photo', (tester) async {
      await pumpSell(tester, pickImages: () async => [image('a.jpg')]);
      await tapVisible(tester, find.text('Ajouter des photos'));
      expect(find.text('Ajouter des photos (1)'), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Retirer la photo'));

      expect(find.text('Ajouter des photos'), findsOneWidget);
    });

    testWidgets('refus du serveur : messages affichés, formulaire conservé', (
      tester,
    ) async {
      final products = productsWithCategory()
        ..onCreate = (product, intent) async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message': 'Les données sont invalides.',
              'errors': <String, dynamic>{
                'image_files': <String>['Limite de photos du compte dépassée.'],
              },
            });
      final env = await pumpSell(tester, products: products);
      await fillValidForm(tester);

      await tapVisible(tester, publishButton);

      expect(find.text('Limite de photos du compte dépassée.'), findsWidgets);
      expect(env.products.created, hasLength(1));
      expect(find.text('ROUTE /my-products'), findsNothing);
      expect(tester.widget<FilledButton>(publishButton).onPressed, isNotNull);
    });

    testWidgets('catégories indisponibles : nouvel essai', (tester) async {
      var attempts = 0;
      final products = FakeProductRepository()
        ..onCategories = () async {
          attempts++;
          if (attempts == 1) {
            throw ApiError.network();
          }
          return const <Category>[Category(id: 'c1', name: 'Mode')];
        };
      await pumpSell(tester, products: products);
      expect(find.text('Catégories indisponibles.'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(TextButton, 'Réessayer'));

      expect(find.text('Catégories indisponibles.'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });
  });

  group('SellPage — vidéo', () {
    PickedVideo video(String name, [int size = 50 * mb]) =>
        PickedVideo(path: '/tmp/$name', name: name, sizeBytes: size);

    Future<void> fillTextFields(WidgetTester tester) async {
      await tester.enterText(fieldByLabel('Titre'), 'Robe wax');
      await chooseCategory(tester, 'Mode');
      await tester.enterText(fieldByLabel('Prix (FCFA)'), '15000');
    }

    testWidgets('vidéo seule : envoyée puis rattachée à l\'annonce', (
      tester,
    ) async {
      final env = await pumpSell(
        tester,
        pickVideo: () async => video('clip.mp4'),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));

      expect(env.products.uploadedVideos.single.name, 'clip.mp4');
      expect(find.textContaining('clip.mp4 · 50 Mo'), findsOneWidget);
      expect(find.textContaining('Vidéo envoyée'), findsOneWidget);

      await fillTextFields(tester);
      await tapVisible(tester, publishButton);

      final (product, intent) = env.products.created.single;
      expect(intent, PublishIntent.publish);
      expect(product.videoId, 'vid1');
      expect(product.poster, isNull);
      expect(find.text('ROUTE /my-products'), findsOneWidget);
    });

    testWidgets('vidéo de plus de 500 Mo ou format inconnu : refusée', (
      tester,
    ) async {
      var next = video('gros.mp4', 500 * mb + 1);
      final env = await pumpSell(tester, pickVideo: () async => next);

      await tapVisible(tester, find.text('Choisir une vidéo'));
      expect(
        find.text('La vidéo ne doit pas dépasser 500 Mo.'),
        findsOneWidget,
      );

      next = video('film.mkv');
      await tapVisible(tester, find.text('Choisir une vidéo'));
      expect(find.textContaining('MP4, MOV, AVI ou WebM'), findsWidgets);
      expect(env.products.uploadedVideos, isEmpty);
    });

    testWidgets('vidéo de plus de 200 Mo : avertissement avant l\'envoi', (
      tester,
    ) async {
      final env = await pumpSell(
        tester,
        pickVideo: () async => video('lourde.mp4', 250 * mb),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));
      expect(find.text('Vidéo volumineuse'), findsOneWidget);
      expect(find.textContaining('250 Mo'), findsOneWidget);

      await tapVisible(tester, find.text('Annuler'));
      expect(env.products.uploadedVideos, isEmpty);

      await tapVisible(tester, find.text('Choisir une vidéo'));
      await tapVisible(tester, find.text('Envoyer quand même'));
      expect(env.products.uploadedVideos, hasLength(1));
    });

    testWidgets('exactement 200 Mo : pas d\'avertissement', (tester) async {
      final env = await pumpSell(
        tester,
        pickVideo: () async => video('limite.mp4', 200 * mb),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));

      expect(find.text('Vidéo volumineuse'), findsNothing);
      expect(env.products.uploadedVideos, hasLength(1));
    });

    testWidgets('annuler l\'envoi en cours', (tester) async {
      final gate = Completer<UploadedVideo>();
      final products = productsWithCategory()
        ..onUploadVideo = (video, token, onProgress) {
          token!.whenCancel.then((_) {
            if (!gate.isCompleted) {
              gate.completeError(ApiError.cancelled());
            }
          });
          return gate.future;
        };
      await pumpSell(
        tester,
        products: products,
        pickVideo: () async => video('clip.mp4'),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));
      expect(find.textContaining('Envoi de la vidéo'), findsWidgets);

      await tapVisible(tester, find.text("Annuler l'envoi"));

      expect(find.text('Choisir une vidéo'), findsOneWidget);
      expect(find.textContaining('Envoi de la vidéo…'), findsNothing);
    });

    testWidgets('publier pendant l\'envoi : refusé', (tester) async {
      final gate = Completer<UploadedVideo>();
      final products = productsWithCategory()
        ..onUploadVideo = (video, token, onProgress) => gate.future;
      final env = await pumpSell(
        tester,
        products: products,
        pickVideo: () async => video('clip.mp4'),
      );
      await tapVisible(tester, find.text('Choisir une vidéo'));
      await fillTextFields(tester);

      await tapVisible(tester, publishButton);

      expect(
        find.text("Patientez : la vidéo est en cours d'envoi."),
        findsOneWidget,
      );
      expect(env.products.created, isEmpty);
      gate.complete(const UploadedVideo(id: 'vid1'));
      await tester.pumpAndSettle();
    });

    testWidgets('vidéo bloquée par la modération : message du serveur', (
      tester,
    ) async {
      final products = productsWithCategory()
        ..onUploadVideo = (video, token, onProgress) async =>
            throw ApiError.fromResponse(422, <String, dynamic>{
              'message':
                  'Cette vidéo a été retirée par la modération et ne peut pas '
                  'être publiée à nouveau.',
              'code': 'video_blocked',
            });
      await pumpSell(
        tester,
        products: products,
        pickVideo: () async => video('clip.mp4'),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));

      expect(find.textContaining('retirée par la modération'), findsOneWidget);
      expect(find.text('Choisir une vidéo'), findsOneWidget);
    });

    testWidgets('vidéo déjà connue du compte : reprise signalée', (
      tester,
    ) async {
      final products = productsWithCategory()
        ..onUploadVideo = (video, token, onProgress) async =>
            const UploadedVideo(id: 'vid-old', alreadyOnServer: true);
      await pumpSell(
        tester,
        products: products,
        pickVideo: () async => video('clip.mp4'),
      );

      await tapVisible(tester, find.text('Choisir une vidéo'));

      expect(find.textContaining('déjà sur QUINCH'), findsOneWidget);
      expect(find.textContaining('Vidéo envoyée'), findsOneWidget);
    });

    testWidgets('retirer la vidéo', (tester) async {
      await pumpSell(tester, pickVideo: () async => video('clip.mp4'));
      await tapVisible(tester, find.text('Choisir une vidéo'));

      await tapVisible(tester, find.byTooltip('Retirer la vidéo'));

      expect(find.text('Choisir une vidéo'), findsOneWidget);
    });

    testWidgets('information sur les frais : seulement hors bêta', (
      tester,
    ) async {
      final premium = FakePremiumRepository()
        ..onConfig = () async => const PublicConfig(
          beta: false,
          listingFeeWithVideo: 150,
          premiumOfferSlots: 100,
          premiumPayments: true,
        );
      await pumpSell(tester, premium: premium);
      expect(
        find.textContaining('Publier avec une vidéo coûte'),
        findsOneWidget,
      );
      expect(find.textContaining('150'), findsWidgets);
    });

    testWidgets('bêta : aucune mention de frais', (tester) async {
      await pumpSell(tester);

      expect(find.textContaining('Publier avec une vidéo coûte'), findsNothing);
    });
  });

  group('SellPage — frais de publication', () {
    ProductSaveResult needsFee(String url) => ProductSaveResult(
      product: sampleCard(),
      message: 'Un dernier pas',
      paymentUrl: url,
      fee: 150,
    );

    Future<ScreenEnv> publishWithVideo(
      WidgetTester tester,
      FakeProductRepository products,
      List<Uri> opened,
    ) async {
      final env = await pumpSell(
        tester,
        products: products,
        pickVideo: () async =>
            PickedVideo(path: '/tmp/c.mp4', name: 'c.mp4', sizeBytes: mb),
        openedUrls: opened,
      );
      await tapVisible(tester, find.text('Choisir une vidéo'));
      await tester.enterText(fieldByLabel('Titre'), 'Robe');
      await chooseCategory(tester, 'Mode');
      await tester.enterText(fieldByLabel('Prix (FCFA)'), '1000');
      await tapVisible(tester, publishButton);
      return env;
    }

    testWidgets('« Payer » ouvre la page de paiement, sans rien confirmer', (
      tester,
    ) async {
      final opened = <Uri>[];
      final products = productsWithCategory()
        ..onCreate = (p, i) async => needsFee('https://pay.example/abc');
      await publishWithVideo(tester, products, opened);

      expect(find.text('Frais de publication vidéo'), findsOneWidget);
      expect(find.textContaining('reste en brouillon'), findsOneWidget);
      await tapVisible(tester, find.text('Payer'));

      expect(opened, [Uri.parse('https://pay.example/abc')]);
      expect(find.text(listingFeePendingMessage), findsOneWidget);
      expect(find.text('ROUTE /my-products'), findsOneWidget);
    });

    testWidgets('« Plus tard » : brouillon conservé, rien d\'ouvert', (
      tester,
    ) async {
      final opened = <Uri>[];
      final products = productsWithCategory()
        ..onCreate = (p, i) async => needsFee('https://pay.example/abc');
      await publishWithVideo(tester, products, opened);

      await tapVisible(tester, find.text('Plus tard'));

      expect(opened, isEmpty);
      expect(find.text(listingFeeLaterMessage), findsOneWidget);
      expect(find.text('ROUTE /my-products'), findsOneWidget);
    });

    testWidgets('adresse de paiement non https : jamais ouverte', (
      tester,
    ) async {
      final opened = <Uri>[];
      final products = productsWithCategory()
        ..onCreate = (p, i) async => needsFee('http://pay.example/abc');
      await publishWithVideo(tester, products, opened);

      await tapVisible(tester, find.text('Payer'));

      expect(opened, isEmpty);
      expect(find.text(listingFeeLinkUnavailableMessage), findsOneWidget);
    });
  });

  testWidgets('Mes annonces : le bouton « Publier » ouvre le formulaire', (
    tester,
  ) async {
    await pumpScreen(tester, const MyProductsPage());

    await tapVisible(tester, find.text('Publier'));

    expect(find.text('ROUTE /sell'), findsOneWidget);
  });
}

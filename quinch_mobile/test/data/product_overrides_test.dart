import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/features/product/product_providers.dart';
import 'package:quinch_mobile/shared/paging/paged_notifier.dart';

import '../support/fakes.dart';

void main() {
  late FakeProductRepository products;
  late FakeFavoritesRepository favorites;
  late ProviderContainer container;

  ProductOverridesController controller() =>
      container.read(productOverridesProvider.notifier);
  Map<String, ProductOverride> overrides() =>
      container.read(productOverridesProvider);

  setUp(() {
    products = FakeProductRepository();
    favorites = FakeFavoritesRepository();
    container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(products),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    addTearDown(container.dispose);
  });

  group('j\'aime', () {
    test('affichage immédiat, puis valeurs du serveur', () async {
      final card = sampleCard(likes: 4);
      final pending = Completer<LikeResult>();
      products.onLike = (id) => pending.future;

      final action = controller().toggleLike(card);
      expect(overrides()[card.id]?.isLiked, isTrue);
      expect(overrides()[card.id]?.likeCount, 5);

      pending.complete(const LikeResult(liked: true, likeCount: 9));
      await action;
      expect(overrides()[card.id]?.likeCount, 9);
      expect(overrides()[card.id]?.liked(card), isTrue);
    });

    test('retirer un « j\'aime » ne descend jamais sous zéro', () async {
      final card = sampleCard(liked: true, likes: 0);
      products.onLike = (id) async =>
          const LikeResult(liked: false, likeCount: 0);
      final action = controller().toggleLike(card);
      expect(overrides()[card.id]?.likeCount, 0);
      await action;
    });

    test('échec : état précédent rétabli et erreur relancée', () async {
      final card = sampleCard(likes: 4);
      products.onLike = (id) async => throw ApiError.network();
      await expectLater(
        controller().toggleLike(card),
        throwsA(isA<ApiError>()),
      );
      expect(overrides().containsKey(card.id), isFalse);
    });

    test('le serveur a le dernier mot si l\'état local divergeait', () async {
      final card = sampleCard(liked: false, likes: 4);
      products.onLike = (id) async =>
          const LikeResult(liked: false, likeCount: 4);
      await controller().toggleLike(card);
      expect(overrides()[card.id]?.liked(card), isFalse);
      expect(overrides()[card.id]?.likes(card), 4);
    });
  });

  group('favoris', () {
    test('enregistrer : état réel du serveur', () async {
      final card = sampleCard();
      products.onToggleSave = (id) async => true;
      await controller().toggleSave(card);
      expect(overrides()[card.id]?.saved(card), isTrue);
    });

    test('échec : rétabli', () async {
      final card = sampleCard(saved: true);
      products.onToggleSave = (id) async => throw ApiError.timeout();
      await expectLater(
        controller().toggleSave(card),
        throwsA(isA<ApiError>()),
      );
      expect(overrides().containsKey(card.id), isFalse);
    });

    test(
      'retirer un favori le fait disparaître de la liste déjà chargée',
      () async {
        final a = sampleCard(id: 'a', slug: 'a');
        final b = sampleCard(id: 'b', slug: 'b');
        favorites.onList = (page) async => pageOf<FavoriteEntry>(
          <FavoriteEntry>[sampleFavorite(a), sampleFavorite(b)],
        );
        await container.read(favoritesProvider.notifier).refresh();

        products.onToggleSave = (id) async => false;
        await controller().toggleSave(a);

        expect(
          container.read(favoritesProvider).items.map((e) => e.productId),
          <String>['b'],
        );
      },
    );

    test(
      'ajouter un favori recharge la liste si elle a déjà été chargée',
      () async {
        favorites.onList = (page) async =>
            pageOf<FavoriteEntry>(<FavoriteEntry>[]);
        await container.read(favoritesProvider.notifier).refresh();
        expect(favorites.listCalls, 1);

        products.onToggleSave = (id) async => true;
        await controller().toggleSave(sampleCard());
        await pumpEventQueue();
        expect(favorites.listCalls, 2);
      },
    );

    test('liste jamais ouverte : aucun rechargement inutile', () async {
      products.onToggleSave = (id) async => true;
      await controller().toggleSave(sampleCard());
      expect(favorites.listCalls, 0);
      expect(container.read(favoritesProvider).status, PagedStatus.idle);
    });
  });
}

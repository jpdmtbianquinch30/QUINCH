import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../data/models/paginated.dart';
import '../../data/models/product.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/paging/paged_notifier.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(apiClientProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------- Feed

class FeedController extends PagedNotifier<ProductCard> {
  FeedController(this.tab);

  final FeedTab tab;

  @override
  Future<Paginated<ProductCard>> fetchPage(int page) =>
      ref.read(productRepositoryProvider).feed(page: page, tab: tab);
}

final feedForYouProvider =
    NotifierProvider<FeedController, PagedState<ProductCard>>(
      () => FeedController(FeedTab.forYou),
    );

final feedFollowingProvider =
    NotifierProvider<FeedController, PagedState<ProductCard>>(
      () => FeedController(FeedTab.following),
    );

// ------------------------------------------------------------ Explorer

class ExploreFilters {
  const ExploreFilters({
    this.categoryId,
    this.type,
    this.priceMin,
    this.priceMax,
    this.sort,
  });

  final String? categoryId;

  /// `product` ou `service` ; null = tous.
  final String? type;
  final int? priceMin;
  final int? priceMax;
  final ExploreSort? sort;

  bool get isDefault =>
      categoryId == null &&
      type == null &&
      priceMin == null &&
      priceMax == null &&
      sort == null;

  /// Nombre de filtres actifs hors type (affiché sur le bouton « Filtres »).
  int get activeCount =>
      (categoryId != null ? 1 : 0) +
      (priceMin != null || priceMax != null ? 1 : 0) +
      (sort != null ? 1 : 0);
}

class ExploreFiltersController extends Notifier<ExploreFilters> {
  @override
  ExploreFilters build() => const ExploreFilters();

  void set(ExploreFilters filters) => state = filters;
}

final exploreFiltersProvider =
    NotifierProvider<ExploreFiltersController, ExploreFilters>(
      ExploreFiltersController.new,
    );

class ExploreController extends PagedNotifier<ProductCard> {
  @override
  Future<Paginated<ProductCard>> fetchPage(int page) {
    final f = ref.read(exploreFiltersProvider);
    return ref
        .read(productRepositoryProvider)
        .explore(
          page: page,
          categoryId: f.categoryId,
          type: f.type,
          priceMin: f.priceMin,
          priceMax: f.priceMax,
          sort: f.sort,
        );
  }
}

final exploreProvider =
    NotifierProvider<ExploreController, PagedState<ProductCard>>(
      ExploreController.new,
    );

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(productRepositoryProvider).categories(),
);

// ----------------------------------------------------------- Favoris

class FavoritesController extends PagedNotifier<FavoriteEntry> {
  @override
  Future<Paginated<FavoriteEntry>> fetchPage(int page) async {
    final result = await ref.read(favoritesRepositoryProvider).list(page: page);
    // Une annonce supprimée depuis n'a plus rien à afficher.
    return Paginated<FavoriteEntry>(
      items: result.items.where((e) => e.product != null).toList(),
      currentPage: result.currentPage,
      lastPage: result.lastPage,
      total: result.total,
      perPage: result.perPage,
    );
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesController, PagedState<FavoriteEntry>>(
      FavoritesController.new,
    );

// ------------------------------------------------------------- Détail

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, String>(
      (ref, slug) => ref.watch(productRepositoryProvider).detail(slug),
    );

// ------------------------------------------------- « J'aime » et favoris

/// Dernier état connu d'une annonce après une action de l'utilisateur dans
/// cette session. Toutes les listes et le détail lisent la même source, donc
/// restent cohérents sans se recharger. Valeurs vides = on garde celle du serveur.
class ProductOverride {
  const ProductOverride({this.isLiked, this.likeCount, this.isSaved});

  final bool? isLiked;
  final int? likeCount;
  final bool? isSaved;

  ProductOverride copyWith({bool? isLiked, int? likeCount, bool? isSaved}) =>
      ProductOverride(
        isLiked: isLiked ?? this.isLiked,
        likeCount: likeCount ?? this.likeCount,
        isSaved: isSaved ?? this.isSaved,
      );

  bool liked(ProductCard card) => isLiked ?? card.isLiked;
  int likes(ProductCard card) => likeCount ?? card.likeCount;
  bool saved(ProductCard card) => isSaved ?? card.isSaved;
}

class ProductOverridesController
    extends Notifier<Map<String, ProductOverride>> {
  @override
  Map<String, ProductOverride> build() {
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next is SessionUnauthenticated) {
        state = <String, ProductOverride>{};
      }
    });
    return <String, ProductOverride>{};
  }

  void _put(String id, ProductOverride value) {
    state = <String, ProductOverride>{...state, id: value};
  }

  /// Bascule « j'aime » : affichage immédiat, puis valeurs réelles du serveur.
  /// En cas d'échec, l'état précédent est rétabli et l'erreur est relancée.
  Future<void> toggleLike(ProductCard card) async {
    final before = state[card.id];
    final current = before ?? const ProductOverride();
    final wasLiked = current.liked(card);
    final count = current.likes(card);
    _put(
      card.id,
      current.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? (count > 0 ? count - 1 : 0) : count + 1,
      ),
    );
    try {
      final result = await ref.read(productRepositoryProvider).like(card.id);
      _put(
        card.id,
        (state[card.id] ?? current).copyWith(
          isLiked: result.liked,
          likeCount: result.likeCount,
        ),
      );
    } on ApiError {
      _restore(card.id, before);
      rethrow;
    }
  }

  Future<void> toggleSave(ProductCard card) async {
    final before = state[card.id];
    final current = before ?? const ProductOverride();
    _put(card.id, current.copyWith(isSaved: !current.saved(card)));
    try {
      final saved = await ref
          .read(productRepositoryProvider)
          .toggleSave(card.id);
      _put(card.id, (state[card.id] ?? current).copyWith(isSaved: saved));
      if (!saved) {
        ref
            .read(favoritesProvider.notifier)
            .removeWhere((e) => e.productId == card.id);
      } else if (ref.read(favoritesProvider).status != PagedStatus.idle) {
        unawaited(ref.read(favoritesProvider.notifier).refresh());
      }
    } on ApiError {
      _restore(card.id, before);
      rethrow;
    }
  }

  void _restore(String id, ProductOverride? previous) {
    final next = <String, ProductOverride>{...state};
    if (previous == null) {
      next.remove(id);
    } else {
      next[id] = previous;
    }
    state = next;
  }
}

final productOverridesProvider =
    NotifierProvider<ProductOverridesController, Map<String, ProductOverride>>(
      ProductOverridesController.new,
    );

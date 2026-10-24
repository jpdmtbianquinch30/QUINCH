import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../data/models/paginated.dart';

enum PagedStatus { idle, loading, loadingMore, loaded, failed }

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.status = PagedStatus.idle,
    this.page = 0,
    this.hasMore = true,
    this.error,
  });

  final List<T> items;
  final PagedStatus status;
  final int page;
  final bool hasMore;
  final ApiError? error;

  bool get isFirstLoad =>
      items.isEmpty &&
      (status == PagedStatus.idle || status == PagedStatus.loading);
  bool get isEmptyResult => items.isEmpty && status == PagedStatus.loaded;
  bool get isFirstLoadFailure => items.isEmpty && status == PagedStatus.failed;
}

/// Logique commune des listes paginées : chargement initial, « charger la
/// suite » et nouvelle tentative. Les réponses d'un chargement périmé (filtre
/// changé entre-temps) sont ignorées grâce au compteur de génération.
class PagedCore<T> {
  PagedCore({required this.read, required this.write, required this.fetch});

  final PagedState<T> Function() read;
  final void Function(PagedState<T> state) write;

  /// Charge une page (à partir de 1). Peut lever une `ApiError`.
  final Future<Paginated<T>> Function(int page) fetch;

  int _generation = 0;

  /// Recharge depuis la première page (premier affichage, filtre, tirer pour actualiser).
  Future<void> refresh() async {
    final generation = ++_generation;
    write(PagedState<T>(status: PagedStatus.loading));
    await _load(1, generation, replace: true);
  }

  /// Charge la page suivante (ou réessaie après un échec).
  Future<void> loadMore() async {
    final current = read();
    final busy =
        current.status == PagedStatus.loading ||
        current.status == PagedStatus.loadingMore;
    if (busy || !current.hasMore || current.items.isEmpty) {
      return;
    }
    final generation = _generation;
    write(
      PagedState<T>(
        items: current.items,
        status: PagedStatus.loadingMore,
        page: current.page,
        hasMore: current.hasMore,
      ),
    );
    await _load(current.page + 1, generation, replace: false);
  }

  /// Retire des éléments (ex. un favori supprimé) sans recharger.
  void removeWhere(bool Function(T item) test) {
    final current = read();
    write(
      PagedState<T>(
        items: current.items.where((item) => !test(item)).toList(),
        status: current.status,
        page: current.page,
        hasMore: current.hasMore,
        error: current.error,
      ),
    );
  }

  /// Remplace les éléments qui satisfont `test` (ex. une notification lue).
  void updateWhere(bool Function(T item) test, T Function(T item) update) {
    final current = read();
    write(
      PagedState<T>(
        items: current.items
            .map((item) => test(item) ? update(item) : item)
            .toList(),
        status: current.status,
        page: current.page,
        hasMore: current.hasMore,
        error: current.error,
      ),
    );
  }

  Future<void> _load(int page, int generation, {required bool replace}) async {
    try {
      final result = await fetch(page);
      if (generation != _generation) {
        return;
      }
      write(
        PagedState<T>(
          items: replace ? result.items : <T>[...read().items, ...result.items],
          status: PagedStatus.loaded,
          page: result.currentPage,
          hasMore: result.hasMore,
        ),
      );
    } on ApiError catch (e) {
      if (generation != _generation) {
        return;
      }
      final current = read();
      write(
        PagedState<T>(
          items: replace ? <T>[] : current.items,
          status: PagedStatus.failed,
          page: replace ? 0 : current.page,
          hasMore: replace ? true : current.hasMore,
          error: e,
        ),
      );
    }
  }
}

/// Liste paginée sans paramètre (feed, Explorer, favoris).
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  late final PagedCore<T> _core = PagedCore<T>(
    read: () => state,
    write: (value) => state = value,
    fetch: fetchPage,
  );

  /// Charge une page (à partir de 1). Peut lever une `ApiError`.
  Future<Paginated<T>> fetchPage(int page);

  @override
  PagedState<T> build() => PagedState<T>();

  Future<void> refresh() => _core.refresh();

  Future<void> loadMore() => _core.loadMore();

  void removeWhere(bool Function(T item) test) => _core.removeWhere(test);

  void updateWhere(bool Function(T item) test, T Function(T item) update) =>
      _core.updateWhere(test, update);
}

/// Liste paginée paramétrée (ex. annonces d'un vendeur), libérée quand l'écran
/// n'est plus affiché. Le paramètre est disponible via `arg`.
abstract class PagedFamilyNotifier<T, A>
    extends AutoDisposeFamilyNotifier<PagedState<T>, A> {
  late final PagedCore<T> _core = PagedCore<T>(
    read: () => state,
    write: (value) => state = value,
    fetch: fetchPage,
  );

  Future<Paginated<T>> fetchPage(int page);

  @override
  PagedState<T> build(A arg) => PagedState<T>();

  Future<void> refresh() => _core.refresh();

  Future<void> loadMore() => _core.loadMore();

  void removeWhere(bool Function(T item) test) => _core.removeWhere(test);

  void updateWhere(bool Function(T item) test, T Function(T item) update) =>
      _core.updateWhere(test, update);
}

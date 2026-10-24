import '../../core/json/json_utils.dart';

/// Pagination Laravel. Deux variantes existent dans l'API (vérifié) :
/// - paginateur standard : `data`, `current_page`, `last_page`, `total`, `per_page`
///   (feed, conversations, favoris, mes annonces, produits d'un vendeur) ;
/// - enveloppe `meta` : `data` + `meta.{current_page,last_page,total}` (notifications).
/// L'Explorer (`GET products`) renvoie `data` + les mêmes quatre clés à plat.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  bool get hasMore => currentPage < lastPage;

  factory Paginated.fromJson(Object? body, T Function(Json) parse) {
    final m = asMap(body);
    final meta = asMap(m['meta']);
    int pick(String key, int fallback) => asInt(m[key] ?? meta[key], fallback);
    final items = asMapList(m['data']).map(parse).toList();
    return Paginated<T>(
      items: items,
      currentPage: pick('current_page', 1),
      lastPage: pick('last_page', 1),
      total: pick('total', items.length),
      perPage: pick('per_page', 0),
    );
  }
}

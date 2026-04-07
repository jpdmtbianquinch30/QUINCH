import 'package:flutter/foundation.dart';
import '../models/favorite.dart';
import '../services/favorite_service.dart';

class FavoriteProvider extends ChangeNotifier {
  final FavoriteService _favoriteService;

  List<FavoriteItem> _favorites = [];
  List<FavoriteCollection> _collections = [];
  int _count = 0;
  bool _isLoading = false;

  FavoriteProvider(this._favoriteService);

  List<FavoriteItem> get favorites => _favorites;
  List<FavoriteCollection> get collections => _collections;
  int get count => _count;
  bool get isLoading => _isLoading;

  Future<void> loadFavorites({String? collectionId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _favorites =
          await _favoriteService.getFavorites(collectionId: collectionId);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCollections() async {
    try {
      _collections = await _favoriteService.getCollections();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> toggleFavorite(String productId) async {
    try {
      final result = await _favoriteService.toggleFavorite(productId);
      await loadFavorites();
      await loadCount();
      return result['is_saved'] ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCount() async {
    try {
      _count = await _favoriteService.getCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> createCollection(String name) async {
    try {
      await _favoriteService.createCollection(name);
      await loadCollections();
    } catch (_) {}
  }
}

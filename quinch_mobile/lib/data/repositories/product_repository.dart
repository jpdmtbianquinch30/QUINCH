import 'package:dio/dio.dart';

import '../../core/json/json_utils.dart';
import '../../core/media/picked_video.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../api/endpoints.dart';
import '../models/new_product.dart';
import '../models/paginated.dart';
import '../models/product.dart';

enum FeedTab {
  forYou('foryou'),
  following('following');

  const FeedTab(this.value);
  final String value;
}

/// Tri de l'Explorer (`sort_by`). Sans valeur, le serveur trie par date récente.
enum ExploreSort {
  recent('recent'),
  popular('popular'),
  priceAsc('price_asc'),
  priceDesc('price_desc');

  const ExploreSort(this.value);
  final String value;
}

/// Accès aux annonces. Les noms de paramètres sont ceux LUS dans le backend :
/// l'Explorer attend `price_min` / `price_max` / `sort_by` (pas `min_price`,
/// que seul le feed lit) et ignore tout filtre d'état.
class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  /// Feed : uniquement les annonces avec vidéo. Tri serveur stable : la
  /// pagination par `page` est sûre.
  Future<Paginated<ProductCard>> feed({
    int page = 1,
    int perPage = 10,
    FeedTab tab = FeedTab.forYou,
  }) async {
    final body = await _api.get(
      Endpoints.feed,
      query: <String, Object?>{
        'page': page,
        'per_page': perPage,
        'tab': tab.value,
      },
    );
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  Future<Paginated<ProductCard>> explore({
    int page = 1,
    int perPage = 20,
    String? query,
    String? categoryId,
    String? type,
    int? priceMin,
    int? priceMax,
    ExploreSort? sort,
  }) async {
    final params = <String, Object?>{'page': page, 'per_page': perPage};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (categoryId != null) {
      params['category'] = categoryId;
    }
    if (type != null) {
      params['type'] = type;
    }
    if (priceMin != null) {
      params['price_min'] = priceMin;
    }
    if (priceMax != null) {
      params['price_max'] = priceMax;
    }
    if (sort != null) {
      params['sort_by'] = sort.value;
    }
    final body = await _api.get(Endpoints.explorer, query: params);
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  Future<SearchResults> search(String query) async {
    final body = await _api.get(
      Endpoints.search,
      query: <String, Object?>{'q': query.trim()},
    );
    return SearchResults.fromJson(body);
  }

  Future<ProductDetail> detail(String slug) async {
    final body = await _api.get(Endpoints.product(slug));
    return ProductDetail.fromJson(body);
  }

  Future<List<Category>> categories() async {
    final body = await _api.get(Endpoints.categories);
    return asMapList(asMap(body)['categories']).map(Category.fromJson).toList();
  }

  Future<LikeResult> like(String productId) async {
    final body = await _api.post(Endpoints.like(productId));
    return LikeResult.fromJson(body);
  }

  /// Ajoute ou retire des favoris (même table que la page Favoris côté serveur).
  /// Renvoie l'état réel après l'action.
  Future<bool> toggleSave(String productId) async {
    final body = await _api.post(Endpoints.save(productId));
    return asBool(asMap(body)['saved']);
  }

  /// Compte une vue. Meilleur effort : l'appelant ignore l'échec.
  Future<void> recordView(String productId) async {
    await _api.post(Endpoints.view(productId));
  }

  /// Mes annonces, tous statuts confondus (brouillons inclus), 20 par page.
  Future<Paginated<ProductCard>> myProducts({int page = 1}) async {
    final body = await _api.get(
      Endpoints.myProducts,
      query: <String, Object?>{'page': page},
    );
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  /// `POST products` (multipart) : crée un produit, en brouillon ou publié.
  /// Si des frais de publication sont dus, la réponse contient `payment_url`
  /// et l'annonce reste en brouillon : seul le serveur confirme le paiement.
  Future<ProductSaveResult> createProduct(
    NewProduct product,
    PublishIntent intent, {
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData();
    void field(String key, String value) =>
        form.fields.add(MapEntry<String, String>(key, value));

    field('title', product.title);
    field('category_id', product.categoryId);
    field('price', product.price.toString());
    field('type', 'product');
    field('condition', product.condition.value);
    field('is_negotiable', product.isNegotiable ? '1' : '0');
    field('stock_quantity', product.stockQuantity.toString());
    if (product.description.isNotEmpty) {
      field('description', product.description);
    }
    field('intent', intent.value);

    final videoId = product.videoId;
    if (videoId != null) {
      field('video_id', videoId);
    }
    final poster = product.poster;
    if (poster != null) {
      form.files.add(
        MapEntry<String, MultipartFile>(
          'poster_file',
          await MultipartFile.fromFile(poster.path, filename: poster.name),
        ),
      );
    }
    for (final image in product.images) {
      form.files.add(
        MapEntry<String, MultipartFile>(
          'image_files[]',
          await MultipartFile.fromFile(image.path, filename: image.name),
        ),
      );
    }

    final body = await _api.post(
      Endpoints.createProduct,
      data: form,
      // Plusieurs photos sur réseau lent : plus long que le délai par défaut.
      options: Options(sendTimeout: const Duration(minutes: 5)),
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call(sent / total);
        }
      },
    );
    return ProductSaveResult.fromJson(body);
  }

  /// `POST products/upload-video` (multipart, champ `video`, 500 Mo maximum,
  /// 5 envois par minute). La vidéo est ensuite traitée par le serveur
  /// (miniature, durée) ; on la joint à l'annonce avec son identifiant.
  ///
  /// 409 : vidéo déjà connue du serveur. Si elle appartient à ce compte, le
  /// serveur la renvoie et on la reprend ; sinon l'erreur est relancée.
  /// 422 `video_blocked` : retirée par la modération (message du serveur).
  Future<UploadedVideo> uploadVideo(
    PickedVideo video, {
    CancelToken? cancelToken,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData();
    form.files.add(
      MapEntry<String, MultipartFile>(
        'video',
        await MultipartFile.fromFile(video.path, filename: video.name),
      ),
    );
    try {
      final body = await _api.post(
        Endpoints.uploadVideo,
        data: form,
        cancelToken: cancelToken,
        // Jusqu'à 500 Mo sur réseau mobile : très au-delà des délais par défaut.
        // Le serveur calcule l'empreinte du fichier avant de répondre.
        options: Options(
          sendTimeout: const Duration(minutes: 45),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            onProgress?.call(sent / total);
          }
        },
      );
      final id = asStringOrNull(asMap(asMap(body)['video'])['id']);
      if (id == null) {
        throw const ApiError(kind: ApiErrorKind.unknown);
      }
      return UploadedVideo(id: id);
    } on ApiError catch (e) {
      if (e.statusCode == 409) {
        final ownId = asStringOrNull(asMap(e.data['video'])['id']);
        if (ownId != null) {
          return UploadedVideo(id: ownId, alreadyOnServer: true);
        }
      }
      rethrow;
    }
  }

  /// `POST products/{id}/publish` : met un brouillon en ligne. Si des frais sont
  /// dus (compte gratuit, annonce avec vidéo, hors bêta), la réponse contient
  /// `payment_url` et l'annonce reste en brouillon jusqu'à confirmation du
  /// serveur. 422 si l'annonce n'est pas un brouillon.
  Future<ProductSaveResult> publishProduct(String productId) async =>
      ProductSaveResult.fromJson(await _api.post(Endpoints.publish(productId)));

  /// `PUT products/{id}` : modifie les champs autorisés. Un changement de
  /// statut interdit (brouillon, modération) est refusé par le serveur en 422.
  Future<ProductSaveResult> updateProduct(
    String productId,
    ProductUpdate update,
  ) async => ProductSaveResult.fromJson(
    await _api.put(Endpoints.productById(productId), data: update.toJson()),
  );

  /// Supprime une de mes annonces (le serveur vérifie la propriété).
  Future<void> deleteProduct(String productId) async {
    await _api.delete(Endpoints.productById(productId));
  }
}

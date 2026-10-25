import '../../core/media/picked_image.dart';

/// État de l'objet (`condition` de `POST products`).
enum ProductCondition {
  brandNew('new', 'Neuf'),
  likeNew('like_new', 'Comme neuf'),
  good('good', 'Bon état'),
  fair('fair', 'Passable');

  const ProductCondition(this.value, this.label);

  final String value;
  final String label;
}

/// `intent` de `POST products` : brouillon (aucun paiement) ou publication.
enum PublishIntent {
  draft('draft'),
  publish('publish');

  const PublishIntent(this.value);

  final String value;
}

/// Nouvelle annonce de type « produit », telle qu'envoyée à `POST products`.
/// Le serveur exige au moins une couverture, une photo ou une vidéo.
class NewProduct {
  const NewProduct({
    required this.title,
    required this.categoryId,
    required this.price,
    this.poster,
    this.videoId,
    this.description = '',
    this.condition = ProductCondition.brandNew,
    this.isNegotiable = true,
    this.stockQuantity = 1,
    this.images = const <PickedImage>[],
  });

  final String title;
  final String categoryId;

  /// Prix en FCFA, entier.
  final int price;
  final PickedImage? poster;

  /// Identifiant renvoyé par `POST products/upload-video`.
  final String? videoId;
  final String description;
  final ProductCondition condition;
  final bool isNegotiable;
  final int stockQuantity;
  final List<PickedImage> images;
}

/// Résultat de `POST products/upload-video`.
class UploadedVideo {
  const UploadedVideo({required this.id, this.alreadyOnServer = false});

  final String id;

  /// Vrai si le serveur a reconnu une vidéo déjà envoyée par ce même compte
  /// (409) : elle est reprise telle quelle, sans nouvel envoi.
  final bool alreadyOnServer;
}

/// Champs modifiables d'une annonce : exactement ceux que `PUT products/{id}`
/// accepte (titre, description, prix, stock, état, négociable, statut). Les
/// photos, la vidéo et la catégorie ne se modifient pas côté serveur.
class ProductUpdate {
  const ProductUpdate({
    this.title,
    this.description,
    this.price,
    this.stockQuantity,
    this.condition,
    this.isNegotiable,
    this.status,
  });

  final String? title;
  final String? description;
  final int? price;
  final int? stockQuantity;
  final ProductCondition? condition;
  final bool? isNegotiable;
  final String? status;

  bool get isEmpty =>
      title == null &&
      description == null &&
      price == null &&
      stockQuantity == null &&
      condition == null &&
      isNegotiable == null &&
      status == null;

  /// Seuls les champs renseignés sont envoyés (le serveur applique `sometimes`).
  Map<String, Object> toJson() => <String, Object>{
    if (title != null) 'title': title!,
    if (description != null) 'description': description!,
    if (price != null) 'price': price!,
    if (stockQuantity != null) 'stock_quantity': stockQuantity!,
    if (condition != null) 'condition': condition!.value,
    if (isNegotiable != null) 'is_negotiable': isNegotiable!,
    if (status != null) 'status': status!,
  };
}

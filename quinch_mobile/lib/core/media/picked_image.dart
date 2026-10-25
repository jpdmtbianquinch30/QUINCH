/// Image choisie dans la galerie. Aucun contenu en mémoire : seulement le
/// chemin du fichier temporaire, son nom et sa taille.
class PickedImage {
  const PickedImage({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Images de profil envoyées au serveur. Limites lues dans
/// `UserController::uploadAvatar` et `uploadCover` (règles Laravel `max` en
/// kilo-octets : 5120 et 10240) ; formats `jpeg, jpg, png, webp`.
enum ProfileImageKind {
  avatar(
    field: 'avatar',
    maxBytes: 5 * 1024 * 1024,
    maxLabel: '5 Mo',
    successMessage: 'Photo de profil mise à jour.',
  ),
  cover(
    field: 'cover',
    maxBytes: 10 * 1024 * 1024,
    maxLabel: '10 Mo',
    successMessage: 'Photo de couverture mise à jour.',
  );

  const ProfileImageKind({
    required this.field,
    required this.maxBytes,
    required this.maxLabel,
    required this.successMessage,
  });

  /// Nom du champ du formulaire multipart attendu par le serveur.
  final String field;
  final int maxBytes;
  final String maxLabel;
  final String successMessage;
}

const _allowedExtensions = <String>{'jpg', 'jpeg', 'png', 'webp'};

/// Contrôle local avant l'envoi, pour éviter un transfert inutile. Le serveur
/// reste l'autorité : il revérifie le type réel et la taille. Renvoie le message
/// à afficher, ou null si l'image peut être envoyée.
String? validateProfileImage(ProfileImageKind kind, PickedImage image) {
  if (image.sizeBytes <= 0) {
    return 'Cette image est vide ou illisible.';
  }
  final dot = image.name.lastIndexOf('.');
  if (dot >= 0 && dot < image.name.length - 1) {
    final extension = image.name.substring(dot + 1).toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      return 'Format non accepté. Utilisez une image JPEG, PNG ou WebP.';
    }
  }
  if (image.sizeBytes > kind.maxBytes) {
    return 'Cette image dépasse ${kind.maxLabel}. Choisissez-en une plus légère.';
  }
  return null;
}

/// Photos d'une annonce (`poster_file` et `image_files[]` de `POST products`) :
/// 5 Mo maximum chacune (règle Laravel `max:5120`), JPEG, PNG ou WebP.
const listingImageMaxBytes = 5 * 1024 * 1024;

/// Nombre maximal de photos supplémentaires que le serveur accepte dans une
/// requête (`image_files` : `max:10`). La limite réelle du compte (gratuit ou
/// Premium) est appliquée par le serveur, qui répond par un message explicite.
const listingExtraImagesHardMax = 10;

String? validateListingImage(PickedImage image) {
  if (image.sizeBytes <= 0) {
    return 'Cette image est vide ou illisible.';
  }
  final dot = image.name.lastIndexOf('.');
  if (dot >= 0 && dot < image.name.length - 1) {
    final extension = image.name.substring(dot + 1).toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      return 'Format non accepté. Utilisez une image JPEG, PNG ou WebP.';
    }
  }
  if (image.sizeBytes > listingImageMaxBytes) {
    return 'Une photo dépasse 5 Mo. Choisissez-en une plus légère.';
  }
  return null;
}

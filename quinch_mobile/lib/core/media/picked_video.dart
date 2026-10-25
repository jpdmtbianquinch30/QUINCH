/// Vidéo choisie dans la galerie (chemin du fichier, nom, taille).
class PickedVideo {
  const PickedVideo({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// `POST products/upload-video` : `max:512000` (Ko) côté serveur, soit 500 Mo.
const videoMaxBytes = 500 * 1024 * 1024;

/// Au-delà, l'utilisateur est averti que l'envoi sera long et gourmand en
/// données, mais peut continuer.
const videoWarnBytes = 200 * 1024 * 1024;

/// Formats acceptés par le serveur : MP4, MOV (quicktime), AVI, WebM.
const _allowedVideoExtensions = <String>{'mp4', 'mov', 'avi', 'webm'};

/// Contrôle local avant l'envoi. Le serveur reste l'autorité (type réel, taille).
/// Renvoie le message à afficher, ou null si la vidéo peut être envoyée.
String? validateListingVideo(PickedVideo video) {
  if (video.sizeBytes <= 0) {
    return 'Cette vidéo est vide ou illisible.';
  }
  final dot = video.name.lastIndexOf('.');
  if (dot >= 0 && dot < video.name.length - 1) {
    final extension = video.name.substring(dot + 1).toLowerCase();
    if (!_allowedVideoExtensions.contains(extension)) {
      return 'Format vidéo non supporté. Utilisez MP4, MOV, AVI ou WebM.';
    }
  }
  if (video.sizeBytes > videoMaxBytes) {
    return 'La vidéo ne doit pas dépasser 500 Mo.';
  }
  return null;
}

bool videoNeedsSizeWarning(PickedVideo video) =>
    video.sizeBytes > videoWarnBytes;

/// « 230 Mo » (arrondi à l'entier supérieur pour ne pas sous-estimer).
String formatMegabytes(int bytes) => '${(bytes / (1024 * 1024)).ceil()} Mo';

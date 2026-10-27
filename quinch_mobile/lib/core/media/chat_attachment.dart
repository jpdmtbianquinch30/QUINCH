/// Type de pièce jointe envoyable depuis l'application.
enum ChatAttachmentKind { image, video }

/// Pièce jointe choisie dans la galerie (chemin du fichier, nom, taille).
class ChatAttachment {
  const ChatAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.kind,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final ChatAttachmentKind kind;
}

/// `POST conversations/{id}/file` : `max:20480` (Ko) côté serveur, soit 20 Mo.
const chatAttachmentMaxBytes = 20 * 1024 * 1024;

/// Formats acceptés par le serveur pour les pièces jointes du chat. Les images
/// sont toujours acceptées ; les vidéos seulement si `chat_file` est actif.
const _imageExtensions = <String>{'jpg', 'jpeg', 'png', 'webp'};
const _videoExtensions = <String>{'mp4', 'webm', 'mov', 'mkv'};

/// Contrôle local avant l'envoi. Le serveur reste l'autorité (type réel, taille,
/// activation de la fonction). Renvoie le message à afficher, ou null si le
/// fichier peut être envoyé.
String? validateChatAttachment(ChatAttachment file) {
  if (file.sizeBytes <= 0) {
    return 'Ce fichier est vide ou illisible.';
  }
  final dot = file.name.lastIndexOf('.');
  if (dot >= 0 && dot < file.name.length - 1) {
    final extension = file.name.substring(dot + 1).toLowerCase();
    final allowed = file.kind == ChatAttachmentKind.image
        ? _imageExtensions
        : _videoExtensions;
    if (!allowed.contains(extension)) {
      return file.kind == ChatAttachmentKind.image
          ? 'Format non accepté. Utilisez une image JPEG, PNG ou WebP.'
          : 'Format vidéo non accepté. Utilisez MP4, WebM, MOV ou MKV.';
    }
  }
  if (file.sizeBytes > chatAttachmentMaxBytes) {
    return 'Ce fichier dépasse 20 Mo. Choisissez-en un plus léger.';
  }
  return null;
}

/// « 340 Ko », « 2,5 Mo » : taille lisible d'un fichier.
String formatFileSize(int bytes) {
  const mo = 1024 * 1024;
  if (bytes < mo) {
    final ko = (bytes / 1024).ceil();
    return '${ko < 1 ? 1 : ko} Ko';
  }
  return '${(bytes / mo).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}

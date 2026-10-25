import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../media/picked_image.dart';
import '../media/picked_video.dart';

/// Ouvre la galerie et renvoie l'image choisie, ou null si l'utilisateur
/// annule. Surchargeable dans les tests.
///
/// Galerie uniquement : le sélecteur système d'Android n'exige aucune
/// permission, et l'appareil photo n'est pas utilisé.
typedef ImagePick = Future<PickedImage?> Function();

final imagePickProvider = Provider<ImagePick>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) {
      return null;
    }
    return PickedImage(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
    );
  },
);

/// Ouvre la galerie pour choisir plusieurs images (liste vide si annulé).
typedef ImagesPick = Future<List<PickedImage>> Function();

final imagesPickProvider = Provider<ImagesPick>(
  (ref) => () async {
    final files = await ImagePicker().pickMultiImage();
    return <PickedImage>[
      for (final file in files)
        PickedImage(
          path: file.path,
          name: file.name,
          sizeBytes: await file.length(),
        ),
    ];
  },
);

/// Ouvre la galerie pour choisir une vidéo (null si annulé).
typedef VideoPick = Future<PickedVideo?> Function();

final videoPickProvider = Provider<VideoPick>(
  (ref) => () async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return null;
    }
    return PickedVideo(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
    );
  },
);

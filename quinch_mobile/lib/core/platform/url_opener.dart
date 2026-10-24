import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre une adresse hors de l'application (navigateur). Surchargeable dans les tests.
/// Ne sert qu'à des adresses https validées par l'appelant (voir `PaymentStart`).
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

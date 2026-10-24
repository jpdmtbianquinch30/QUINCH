import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import 'config/app_config.dart';
import 'config/media_url.dart';
import 'network/api_client.dart';
import 'network/auth_token_holder.dart';
import 'network/dio_factory.dart';
import 'session/session_controller.dart';
import 'storage/token_storage.dart';

/// Doit être surchargé dans `main()` avec la configuration validée.
final appConfigProvider = Provider<AppConfig>(
  (ref) =>
      throw StateError('appConfigProvider doit être surchargé au démarrage.'),
);

/// Résolution des URLs de médias (vidéos et miniatures sont relatives au serveur).
final mediaUrlProvider = Provider<MediaUrl>(
  (ref) => ref.watch(appConfigProvider).media,
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final authTokenHolderProvider = Provider<AuthTokenHolder>(
  (ref) => AuthTokenHolder(),
);

/// Horloge injectable (tests de rafraîchissement du jeton).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final dioProvider = Provider<Dio>(
  (ref) => createDio(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(authTokenHolderProvider),
  ),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    dio: ref.watch(dioProvider),
    tokens: ref.watch(authTokenHolderProvider),
    // Lecture différée : évite une dépendance circulaire à la construction.
    onSessionInvalid: (error) => ref
        .read(sessionControllerProvider.notifier)
        .handleSessionInvalid(error),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

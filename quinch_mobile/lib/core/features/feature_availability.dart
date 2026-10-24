import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/endpoints.dart';
import '../network/api_error.dart';
import '../providers.dart';
import '../session/session_controller.dart';
import '../session/session_state.dart';

/// Fonctionnalités que le serveur peut activer ou couper à chaud
/// (middleware `feature:*`). L'état n'est exposé par aucune route : il est
/// déduit d'appels réels, jamais supposé.
enum AppFeature {
  negotiation,
  follow,
  badges,
  favoritesCollections,
  reviews,
  sharing,
  chatAudio,
  chatFile,
}

enum FeatureStatus { unknown, available, unavailable }

/// Règle de décision (voir rapport de l'étape 3, §5) :
/// - un appel réussi prouve que la fonction est disponible ;
/// - seul un 404 SANS message sur une route connue pour être sous drapeau
///   la fait considérer comme indisponible ;
/// - toute autre erreur (réseau, 5xx, 401, route inexistante, ressource
///   absente) laisse l'état inchangé : on ne sait pas.
/// C'est une déduction à partir du code du backend, pas une certitude : l'écran
/// parle donc d'« indisponible pour le moment », jamais de « désactivée ».
FeatureStatus statusAfterCall(FeatureStatus current, {ApiError? error}) {
  if (error == null) {
    return FeatureStatus.available;
  }
  if (error.kind == ApiErrorKind.notFoundEmptyMessage) {
    return FeatureStatus.unavailable;
  }
  return current;
}

/// Routes de sondage : GET sans identifiant de ressource, donc sans 404 possible
/// de type « ressource absente ».
const Map<AppFeature, String> featureProbePaths = <AppFeature, String>{
  AppFeature.negotiation: Endpoints.negotiations,
  AppFeature.follow: Endpoints.myFollowers,
  AppFeature.badges: Endpoints.badgesDefinitions,
  AppFeature.favoritesCollections: Endpoints.favoritesCollections,
};

/// Exécute un sondage. Surchargeable dans les tests.
typedef FeatureProbe = Future<void> Function(String path);

final featureProbeProvider = Provider<FeatureProbe>(
  (ref) => (path) async {
    await ref.read(apiClientProvider).get(path);
  },
);

class FeatureAvailabilityController
    extends Notifier<Map<AppFeature, FeatureStatus>> {
  @override
  Map<AppFeature, FeatureStatus> build() {
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next is SessionAuthenticated && previous is! SessionAuthenticated) {
        unawaited(probe());
      } else if (next is SessionUnauthenticated) {
        state = _initial();
      }
    });
    return _initial();
  }

  static Map<AppFeature, FeatureStatus> _initial() =>
      <AppFeature, FeatureStatus>{
        for (final feature in AppFeature.values) feature: FeatureStatus.unknown,
      };

  /// Sonde les fonctions qui ont une route de test. L'état n'est pas conservé
  /// entre deux lancements : il est recalculé à chaque connexion.
  Future<void> probe() async {
    final run = ref.read(featureProbeProvider);
    await Future.wait(
      featureProbePaths.entries.map((entry) async {
        ApiError? failure;
        try {
          await run(entry.value);
        } on ApiError catch (e) {
          failure = e;
        }
        report(entry.key, error: failure);
      }),
    );
  }

  /// À appeler avec le résultat d'un appel réel d'une fonctionnalité sous drapeau.
  void report(AppFeature feature, {ApiError? error}) {
    final current = state[feature] ?? FeatureStatus.unknown;
    final next = statusAfterCall(current, error: error);
    if (next != current) {
      state = <AppFeature, FeatureStatus>{...state, feature: next};
    }
  }
}

final featureAvailabilityProvider =
    NotifierProvider<
      FeatureAvailabilityController,
      Map<AppFeature, FeatureStatus>
    >(FeatureAvailabilityController.new);

/// Vrai tant que la fonction n'est pas connue comme indisponible. Quand l'état
/// est inconnu, l'écran la propose ; si l'action échoue, `report` la masquera.
final featureEnabledProvider = Provider.family<bool, AppFeature>(
  (ref, feature) => ref.watch(
    featureAvailabilityProvider.select(
      (m) => m[feature] != FeatureStatus.unavailable,
    ),
  ),
);

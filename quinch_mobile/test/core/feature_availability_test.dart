import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quinch_mobile/core/features/feature_availability.dart';
import 'package:quinch_mobile/core/network/api_error.dart';
import 'package:quinch_mobile/core/providers.dart';
import 'package:quinch_mobile/core/session/session_controller.dart';
import 'package:quinch_mobile/data/api/endpoints.dart';

import '../support/fakes.dart';

ApiError emptyNotFound() =>
    ApiError.fromResponse(404, <String, dynamic>{'message': ''});

void main() {
  group('statusAfterCall', () {
    test('succès : disponible', () {
      expect(statusAfterCall(FeatureStatus.unknown), FeatureStatus.available);
      expect(
        statusAfterCall(FeatureStatus.unavailable),
        FeatureStatus.available,
      );
    });

    test('404 sans message : indisponible', () {
      expect(
        statusAfterCall(FeatureStatus.unknown, error: emptyNotFound()),
        FeatureStatus.unavailable,
      );
    });

    test('autres erreurs : l\'état ne change pas', () {
      final others = <ApiError>[
        ApiError.network(),
        ApiError.timeout(),
        ApiError.fromResponse(500, <String, dynamic>{}),
        ApiError.fromResponse(401, <String, dynamic>{}),
        ApiError.fromResponse(404, <String, dynamic>{
          'message': 'The route api/v1/negotiations could not be found.',
        }),
        ApiError.fromResponse(404, <String, dynamic>{
          'message': 'No query results for model [X].',
        }),
      ];
      for (final error in others) {
        expect(
          statusAfterCall(FeatureStatus.unknown, error: error),
          FeatureStatus.unknown,
        );
        expect(
          statusAfterCall(FeatureStatus.available, error: error),
          FeatureStatus.available,
        );
      }
    });
  });

  group('FeatureAvailabilityController', () {
    late FakeAuthRepository repo;
    late InMemoryTokenStorage storage;
    late List<String> probed;
    late Map<String, Object> outcomes;
    late ProviderContainer container;

    setUp(() {
      repo = FakeAuthRepository();
      storage = InMemoryTokenStorage();
      probed = <String>[];
      outcomes = <String, Object>{};
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          tokenStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 19)),
          featureProbeProvider.overrideWithValue((path) async {
            probed.add(path);
            final outcome = outcomes[path];
            if (outcome is ApiError) {
              throw outcome;
            }
          }),
        ],
      );
      addTearDown(container.dispose);
    });

    Map<AppFeature, FeatureStatus> statuses() =>
        container.read(featureAvailabilityProvider);

    test('état initial : tout est inconnu', () {
      expect(statuses().values.toSet(), <FeatureStatus>{FeatureStatus.unknown});
    });

    test('probe : chaque résultat est interprété séparément', () async {
      outcomes[Endpoints.negotiations] = emptyNotFound();
      outcomes[Endpoints.badgesDefinitions] = ApiError.network();
      outcomes[Endpoints.favoritesCollections] = ApiError.fromResponse(
        404,
        <String, dynamic>{
          'message':
              'The route api/v1/favorites/collections could not be found.',
        },
      );
      await container.read(featureAvailabilityProvider.notifier).probe();

      expect(statuses()[AppFeature.negotiation], FeatureStatus.unavailable);
      expect(statuses()[AppFeature.follow], FeatureStatus.available);
      expect(statuses()[AppFeature.badges], FeatureStatus.unknown);
      expect(
        statuses()[AppFeature.favoritesCollections],
        FeatureStatus.unknown,
      );
      // Pas de sonde pour les fonctions sans route sans identifiant.
      expect(statuses()[AppFeature.reviews], FeatureStatus.unknown);
      expect(probed.toSet(), featureProbePaths.values.toSet());
    });

    test(
      'la connexion déclenche les sondes, la déconnexion remet tout à inconnu',
      () async {
        container.read(
          featureAvailabilityProvider,
        ); // active l'écoute de la session
        outcomes[Endpoints.negotiations] = emptyNotFound();
        storage.token = 'tok';
        storage.issuedAt = DateTime.utc(2026, 10, 18);

        await container.read(sessionControllerProvider.notifier).start();
        await pumpEventQueue();

        expect(probed.toSet(), featureProbePaths.values.toSet());
        expect(statuses()[AppFeature.negotiation], FeatureStatus.unavailable);
        expect(statuses()[AppFeature.follow], FeatureStatus.available);

        await container.read(sessionControllerProvider.notifier).logout();
        await pumpEventQueue();
        expect(statuses().values.toSet(), <FeatureStatus>{
          FeatureStatus.unknown,
        });
      },
    );

    test('report : un échec d\'usage peut masquer, un succès rétablit', () {
      final notifier = container.read(featureAvailabilityProvider.notifier);
      notifier.report(AppFeature.sharing, error: emptyNotFound());
      expect(statuses()[AppFeature.sharing], FeatureStatus.unavailable);
      expect(
        container.read(featureEnabledProvider(AppFeature.sharing)),
        isFalse,
      );

      notifier.report(AppFeature.sharing);
      expect(statuses()[AppFeature.sharing], FeatureStatus.available);
      expect(
        container.read(featureEnabledProvider(AppFeature.sharing)),
        isTrue,
      );
    });

    test('fonction inconnue : proposée par défaut', () {
      expect(
        container.read(featureEnabledProvider(AppFeature.reviews)),
        isTrue,
      );
    });
  });
}

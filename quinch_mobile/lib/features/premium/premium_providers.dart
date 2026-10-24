import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/premium.dart';
import '../../data/repositories/premium_repository.dart';
import '../../data/repositories/ranking_repository.dart';

final premiumRepositoryProvider = Provider<PremiumRepository>(
  (ref) => PremiumRepository(ref.watch(apiClientProvider)),
);

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepository(ref.watch(apiClientProvider)),
);

/// Tout ce que l'écran Premium affiche, chargé en parallèle. L'offre de
/// lancement est facultative : si elle échoue, le reste de l'écran s'affiche.
class PremiumOverview {
  const PremiumOverview({
    required this.config,
    required this.plans,
    required this.status,
    this.offer,
  });

  final PublicConfig config;
  final List<PremiumPlan> plans;
  final PremiumStatus status;
  final PremiumOffer? offer;
}

final premiumOverviewProvider = FutureProvider.autoDispose<PremiumOverview>((
  ref,
) async {
  final repo = ref.watch(premiumRepositoryProvider);
  final results = await Future.wait<Object?>(<Future<Object?>>[
    repo.config(),
    repo.plans(),
    repo.status(),
    repo.offer().then<PremiumOffer?>(
      (offer) => offer,
      onError: (Object error) => null,
    ),
  ]);
  return PremiumOverview(
    config: results[0]! as PublicConfig,
    plans: results[1]! as List<PremiumPlan>,
    status: results[2]! as PremiumStatus,
    offer: results[3] as PremiumOffer?,
  );
});

final rankingPreferencesProvider =
    FutureProvider.autoDispose<RankingPreferences>(
      (ref) => ref.watch(rankingRepositoryProvider).preferences(),
    );

final userRankingProvider = FutureProvider.autoDispose
    .family<List<RankingEntry>, RankingKind>(
      (ref, kind) => ref.watch(rankingRepositoryProvider).users(kind),
    );

final productRankingProvider =
    FutureProvider.autoDispose<List<ProductRankingEntry>>(
      (ref) => ref.watch(rankingRepositoryProvider).products(),
    );

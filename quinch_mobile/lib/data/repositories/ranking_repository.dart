import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/premium.dart';

/// Classements (réservés aux comptes Premium : 403 sinon).
enum RankingKind {
  sellers('Vendeurs'),
  products('Annonces'),
  profiles('Profils'),
  followers('Abonnés');

  const RankingKind(this.label);
  final String label;
}

class RankingRepository {
  RankingRepository(this._api);

  final ApiClient _api;

  Future<RankingPreferences> preferences() async =>
      RankingPreferences.fromJson(await _api.get(Endpoints.rankingPreferences));

  /// `PATCH rankings/preferences` : `opt_in` obligatoire, `anonymous` facultatif.
  Future<RankingPreferences> updatePreferences({
    required bool optIn,
    required bool anonymous,
  }) async {
    final body = await _api.patch(
      Endpoints.rankingPreferences,
      data: <String, Object?>{'opt_in': optIn, 'anonymous': anonymous},
    );
    final m = asMap(body);
    return RankingPreferences(
      isPremium: true,
      optIn: asBool(m['ranking_opt_in']),
      anonymous: asBool(m['ranking_anonymous']),
    );
  }

  /// Vendeurs, profils ou abonnés (même forme d'identité, mesures différentes).
  Future<List<RankingEntry>> users(RankingKind kind) async {
    final path = switch (kind) {
      RankingKind.sellers => Endpoints.rankingSellers,
      RankingKind.profiles => Endpoints.rankingProfiles,
      RankingKind.followers => Endpoints.rankingFollowers,
      RankingKind.products => throw ArgumentError(
        'Utiliser products() pour le classement des annonces.',
      ),
    };
    return RankingEntry.listFromBody(await _api.get(path));
  }

  Future<List<ProductRankingEntry>> products() async =>
      ProductRankingEntry.listFromBody(
        await _api.get(Endpoints.rankingProducts),
      );
}

import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/premium.dart';

/// Offres Premium, statut, offre de lancement et paiement.
///
/// Le paiement passe par une page externe (Wave). Retour vers l'application :
/// aucun lien profond n'existe côté serveur ; le seul moyen de savoir si le
/// paiement a abouti est de relire `premium/status`.
class PremiumRepository {
  PremiumRepository(this._api);

  final ApiClient _api;

  /// `GET public-config` (public) : mode bêta, frais, places de l'offre, paiements Premium.
  Future<PublicConfig> config() async =>
      PublicConfig.fromJson(await _api.get(Endpoints.publicConfig));

  Future<List<PremiumPlan>> plans() async {
    final body = await _api.get(Endpoints.premiumPlans);
    return asMapList(asMap(body)['plans']).map(PremiumPlan.fromJson).toList();
  }

  Future<PremiumStatus> status() async =>
      PremiumStatus.fromJson(await _api.get(Endpoints.premiumStatus));

  Future<PremiumOffer> offer() async =>
      PremiumOffer.fromJson(await _api.get(Endpoints.premiumOffer));

  /// 201 : candidature envoyée ; 200 : déjà enregistrée ; 422 : déjà Premium ou
  /// plus de places ; 403 `email_not_verified` : email non vérifié.
  Future<OfferApplyResult> applyOffer() async =>
      OfferApplyResult.fromJson(await _api.post(Endpoints.premiumOfferApply));

  /// Démarre un abonnement : renvoie l'adresse de paiement, à ouvrir hors de
  /// l'application, ou null si le serveur n'en a pas fourni une valide (https).
  /// 403 `premium_coming_soon` tant que les paiements sont coupés (bêta).
  Future<PaymentStart?> subscribe(
    String planId, {
    String paymentMethod = 'wave',
  }) async {
    final body = await _api.post(
      Endpoints.premiumSubscribe,
      data: <String, Object?>{'plan': planId, 'payment_method': paymentMethod},
    );
    return PaymentStart.tryFromJson(body);
  }
}

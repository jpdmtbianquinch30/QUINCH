import '../../core/json/json_utils.dart';

/// `GET public-config` (public, sans authentification). Source de vérité du mode bêta.
class PublicConfig {
  const PublicConfig({
    required this.beta,
    required this.listingFeeWithVideo,
    required this.premiumOfferSlots,
    required this.premiumPayments,
  });

  final bool beta;

  /// Frais (FCFA) d'une annonce avec vidéo pour un compte gratuit ; 0 en bêta.
  final int listingFeeWithVideo;
  final int premiumOfferSlots;

  /// false : aucun abonnement payant possible (`premium/subscribe` répond 403
  /// `premium_coming_soon`).
  final bool premiumPayments;

  factory PublicConfig.fromJson(Object? body) {
    final m = asMap(body);
    return PublicConfig(
      beta: asBool(m['beta']),
      listingFeeWithVideo: asInt(m['listing_fee_with_video']),
      premiumOfferSlots: asInt(m['premium_offer_slots']),
      premiumPayments: asBool(m['premium_payments']),
    );
  }
}

class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.label,
    required this.price,
    required this.currency,
  });

  final String id; // monthly | annual
  final String label;
  final int price;
  final String currency;

  factory PremiumPlan.fromJson(Json j) => PremiumPlan(
    id: asString(j['id']),
    label: asString(j['label']),
    price: asInt(j['price']),
    currency: asString(j['currency'], 'XOF'),
  );
}

class PremiumStatus {
  const PremiumStatus({
    required this.isPremium,
    this.plan,
    this.expiresAt,
    this.daysRemaining,
    this.pendingSubscription,
  });

  final bool isPremium;
  final String? plan;
  final DateTime? expiresAt;
  final int? daysRemaining;

  /// Abonnement en attente de confirmation du paiement par le serveur (brut).
  final Json? pendingSubscription;

  factory PremiumStatus.fromJson(Object? body) {
    final m = asMap(body);
    return PremiumStatus(
      isPremium: asBool(m['is_premium']),
      plan: asStringOrNull(m['plan']),
      expiresAt: asDate(m['expires_at']),
      daysRemaining: m['days_remaining'] == null
          ? null
          : asInt(m['days_remaining']),
      pendingSubscription: asMapOrNull(m['pending_subscription']),
    );
  }
}

/// `GET premium/offer`. `myStatus` : null | pending | granted | rejected.
class PremiumOffer {
  const PremiumOffer({
    required this.slotsTotal,
    required this.slotsLeft,
    required this.days,
    this.myStatus,
  });

  final int slotsTotal;
  final int slotsLeft;
  final int days;
  final String? myStatus;

  factory PremiumOffer.fromJson(Object? body) {
    final m = asMap(body);
    return PremiumOffer(
      slotsTotal: asInt(m['slots_total']),
      slotsLeft: asInt(m['slots_left']),
      days: asInt(m['days']),
      myStatus: asStringOrNull(m['my_status']),
    );
  }
}

/// Démarrage d'un paiement (`premium/subscribe`, `products` ou `products/{id}/publish`).
/// Ce n'est PAS une confirmation : le paiement n'est acquis que lorsque le serveur
/// l'indique ensuite (webhook Wave → `premium/status`, ou annonce `status: active`).
class PaymentStart {
  const PaymentStart({required this.paymentUrl, this.message});

  final Uri paymentUrl;
  final String? message;

  /// Retourne null si l'URL est absente ou n'est pas en https.
  static PaymentStart? tryFromJson(Object? body) {
    final m = asMap(body);
    final raw = asStringOrNull(m['payment_url']);
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return PaymentStart(paymentUrl: uri, message: asStringOrNull(m['message']));
  }
}

/// Ligne d'un classement (`GET rankings/*` → `{ranking: [...]}`), Premium seulement.
/// Les mesures varient selon le classement et sont gardées brutes dans `metrics`.
class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.anonymous,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.metrics = const {},
  });

  final int rank;
  final bool anonymous;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final Json metrics;

  factory RankingEntry.fromJson(Json j) => RankingEntry(
    rank: asInt(j['rank']),
    anonymous: asBool(j['anonymous']),
    fullName: asString(j['full_name']),
    username: asStringOrNull(j['username']),
    avatarUrl: asStringOrNull(j['avatar_url']),
    metrics: Json.from(j)
      ..removeWhere(
        (k, _) => const {
          'rank',
          'anonymous',
          'full_name',
          'username',
          'avatar_url',
          'badges',
        }.contains(k),
      ),
  );

  int metricInt(String key) => asInt(metrics[key]);

  static List<RankingEntry> listFromBody(Object? body) =>
      asMapList(asMap(body)['ranking']).map(RankingEntry.fromJson).toList();
}

/// Ligne du classement des annonces (`GET rankings/products`) : forme différente
/// des trois autres classements (annonce + vendeur, sans identité de profil).
class ProductRankingEntry {
  const ProductRankingEntry({
    required this.rank,
    required this.productId,
    required this.productSlug,
    required this.title,
    required this.viewCount,
    required this.anonymous,
    this.imageUrl,
    this.sellerUsername,
    this.sellerName,
  });

  final int rank;
  final String productId;
  final String productSlug;
  final String title;
  final String? imageUrl;
  final int viewCount;
  final bool anonymous;
  final String? sellerUsername;
  final String? sellerName;

  factory ProductRankingEntry.fromJson(Json j) => ProductRankingEntry(
    rank: asInt(j['rank']),
    productId: asString(j['product_id']),
    productSlug: asString(j['product_slug']),
    title: asString(j['product_title']),
    imageUrl: asStringOrNull(j['product_image']),
    viewCount: asInt(j['view_count']),
    anonymous: asBool(j['anonymous']),
    sellerUsername: asStringOrNull(j['seller_username']),
    sellerName: asStringOrNull(j['seller_name']),
  );

  static List<ProductRankingEntry> listFromBody(Object? body) => asMapList(
    asMap(body)['ranking'],
  ).map(ProductRankingEntry.fromJson).toList();
}

/// `GET rankings/preferences` : `{is_premium, ranking_opt_in, ranking_anonymous}`.
class RankingPreferences {
  const RankingPreferences({
    required this.isPremium,
    required this.optIn,
    required this.anonymous,
  });

  final bool isPremium;
  final bool optIn;
  final bool anonymous;

  factory RankingPreferences.fromJson(Object? body) {
    final m = asMap(body);
    return RankingPreferences(
      isPremium: asBool(m['is_premium']),
      optIn: asBool(m['ranking_opt_in']),
      anonymous: asBool(m['ranking_anonymous']),
    );
  }
}

/// Résultat de `POST premium/offer/apply` : 201 (nouvelle candidature) ou 200
/// (candidature déjà enregistrée), avec `{message, my_status}`.
class OfferApplyResult {
  const OfferApplyResult({required this.myStatus, this.message});

  final String? myStatus;
  final String? message;

  factory OfferApplyResult.fromJson(Object? body) {
    final m = asMap(body);
    return OfferApplyResult(
      myStatus: asStringOrNull(m['my_status']),
      message: asStringOrNull(m['message']),
    );
  }
}

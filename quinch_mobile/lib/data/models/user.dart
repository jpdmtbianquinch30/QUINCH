import '../../core/json/json_utils.dart';

/// Utilisateur connecté.
///
/// Deux formes existent côté serveur (vérifié) :
/// - `AuthController::formatUser` (login, register, refresh, me) : `email_verified`
///   (bool) et `is_premium` calculé sur l'expiration ;
/// - modèle Eloquent brut (`GET user/profile`, `PUT user/profile`, `PUT user/phone`) :
///   pas de `email_verified` mais `email_verified_at` ; `is_premium` est la colonne.
/// Le rôle et le statut premium ne servent qu'à l'affichage : le serveur décide.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.website,
    this.city,
    this.region,
    this.role,
    this.isSeller = false,
    this.isBuyer = false,
    this.emailVerified = false,
    this.onboardingCompleted = false,
    this.isPremium = false,
    this.premiumPlan,
    this.premiumExpiresAt,
    this.trustScore = 0,
    this.createdAt,
  });

  final String id;
  final String email;
  final String username;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? website;
  final String? city;
  final String? region;
  final String? role;
  final bool isSeller;
  final bool isBuyer;
  final bool emailVerified;
  final bool onboardingCompleted;
  final bool isPremium;
  final String? premiumPlan;
  final DateTime? premiumExpiresAt;
  final int trustScore;
  final DateTime? createdAt;

  factory AppUser.fromJson(Json j) {
    final expires = asDate(j['premium_expires_at']);
    final premiumFlag = asBool(j['is_premium']);
    final stillValid = expires == null || expires.isAfter(DateTime.now());
    return AppUser(
      id: asString(j['id']),
      email: asString(j['email']),
      username: asString(j['username']),
      fullName: asString(j['full_name']),
      phoneNumber: asStringOrNull(j['phone_number']),
      avatarUrl: asStringOrNull(j['avatar_url']),
      coverUrl: asStringOrNull(j['cover_url']),
      bio: asStringOrNull(j['bio']),
      website: asStringOrNull(j['website']),
      city: asStringOrNull(j['city']),
      region: asStringOrNull(j['region']),
      role: asStringOrNull(j['role']),
      isSeller: asBool(j['is_seller']),
      isBuyer: asBool(j['is_buyer']),
      emailVerified: j.containsKey('email_verified')
          ? asBool(j['email_verified'])
          : j['email_verified_at'] != null,
      onboardingCompleted: asBool(j['onboarding_completed']),
      isPremium: premiumFlag && stillValid,
      premiumPlan: asStringOrNull(j['premium_plan']),
      premiumExpiresAt: expires,
      trustScore: asInt(j['trust_score']),
      createdAt: asDate(j['created_at']),
    );
  }
}

/// Réponse de login / register / refresh : `{message?, user, token}`.
class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AppUser user;
  final String token;

  factory AuthSession.fromJson(Object? body) {
    final m = asMap(body);
    return AuthSession(
      user: AppUser.fromJson(asMap(m['user'])),
      token: asString(m['token']),
    );
  }
}

/// Profil public d'un vendeur (`GET users/{username}/profile`).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.website,
    this.city,
    this.region,
    this.trustScore = 0,
    this.isPremium = false,
    this.isOnline = false,
    this.memberSince,
    this.productsCount = 0,
    this.soldCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.totalLikes = 0,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.badges = const [],
    this.isFollowing = false,
  });

  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? website;
  final String? city;
  final String? region;
  final int trustScore;
  final bool isPremium;
  final bool isOnline;
  final String? memberSince;
  final int productsCount;
  final int soldCount;
  final int followerCount;
  final int followingCount;
  final int totalLikes;
  final double avgRating;
  final int reviewCount;

  /// Forme exacte de `UserBadge::summaryFor` non confirmée : gardé brut.
  final List<Json> badges;
  final bool isFollowing;

  factory PublicProfile.fromJson(Object? body) {
    final m = asMap(body);
    final u = asMap(m['user']);
    final s = asMap(m['stats']);
    return PublicProfile(
      id: asString(u['id']),
      username: asString(u['username']),
      fullName: asString(u['full_name']),
      avatarUrl: asStringOrNull(u['avatar_url']),
      coverUrl: asStringOrNull(u['cover_url']),
      bio: asStringOrNull(u['bio']),
      website: asStringOrNull(u['website']),
      city: asStringOrNull(u['city']),
      region: asStringOrNull(u['region']),
      trustScore: asInt(u['trust_score']),
      isPremium: asBool(u['is_premium']),
      isOnline: asBool(u['is_online']),
      memberSince: asStringOrNull(u['member_since']),
      productsCount: asInt(s['products_count']),
      soldCount: asInt(s['sold_count']),
      followerCount: asInt(s['follower_count']),
      followingCount: asInt(s['following_count']),
      totalLikes: asInt(s['total_likes']),
      avgRating: asDouble(s['avg_rating']),
      reviewCount: asInt(s['review_count']),
      badges: asMapList(m['badges']),
      isFollowing: asBool(m['is_following']),
    );
  }
}

/// Utilisateur bloqué (`GET users/blocked` renvoie directement une liste).
class BlockedUser {
  const BlockedUser({required this.id, required this.fullName, this.avatarUrl});

  final String id;
  final String fullName;
  final String? avatarUrl;

  factory BlockedUser.fromJson(Json j) => BlockedUser(
    id: asString(j['id']),
    fullName: asString(j['full_name']),
    avatarUrl: asStringOrNull(j['avatar_url']),
  );

  static List<BlockedUser> listFromBody(Object? body) =>
      asMapList(body).map(BlockedUser.fromJson).toList();
}

/// `POST follow/{id}` : `{following: true, is_mutual, message, conversation_id?}` ;
/// `DELETE unfollow/{id}` : `{following: false, message}`.
class FollowResult {
  const FollowResult({
    required this.following,
    required this.isMutual,
    this.message,
  });

  final bool following;
  final bool isMutual;
  final String? message;

  factory FollowResult.fromJson(Object? body) {
    final m = asMap(body);
    return FollowResult(
      following: asBool(m['following']),
      isMutual: asBool(m['is_mutual']),
      message: asStringOrNull(m['message']),
    );
  }
}

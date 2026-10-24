import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:quinch_mobile/core/storage/token_storage.dart';
import 'package:quinch_mobile/data/models/notifications.dart';
import 'package:quinch_mobile/data/models/paginated.dart';
import 'package:quinch_mobile/data/models/premium.dart';
import 'package:quinch_mobile/data/models/product.dart';
import 'package:quinch_mobile/data/models/user.dart';
import 'package:quinch_mobile/data/repositories/auth_repository.dart';
import 'package:quinch_mobile/data/repositories/favorites_repository.dart';
import 'package:quinch_mobile/data/repositories/notification_repository.dart';
import 'package:quinch_mobile/data/repositories/product_repository.dart';
import 'package:quinch_mobile/data/repositories/premium_repository.dart';
import 'package:quinch_mobile/data/repositories/profile_repository.dart';
import 'package:quinch_mobile/data/repositories/ranking_repository.dart';
import 'package:quinch_mobile/data/repositories/safety_repository.dart';

/// Stockage en mémoire : aucune dépendance au Keystore pendant les tests.
class InMemoryTokenStorage implements TokenStorage {
  String? token;
  DateTime? issuedAt;
  int clearCalls = 0;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<DateTime?> readIssuedAt() async => issuedAt;

  @override
  Future<void> writeToken(String token, {required DateTime issuedAt}) async {
    this.token = token;
    this.issuedAt = issuedAt;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    token = null;
    issuedAt = null;
  }
}

AppUser testUser({String name = 'Awa Diop'}) =>
    AppUser.fromJson(<String, dynamic>{
      'id': 'u1',
      'email': 'awa@example.com',
      'username': 'awa',
      'full_name': name,
      'email_verified': true,
    });

AuthSession testSession({String token = 'tok-new'}) =>
    AuthSession(user: testUser(), token: token);

/// Faux dépôt d'authentification : chaque comportement est injecté par le test.
class FakeAuthRepository implements AuthRepository {
  Future<AppUser> Function() onMe = () async => testUser();
  Future<AuthSession> Function() onLogin = () async => testSession();
  Future<AuthSession> Function() onRegister = () async => testSession();
  Future<AuthSession> Function() onRefresh = () async =>
      testSession(token: 'tok-refreshed');
  Future<void> Function() onLogout = () async {};
  Future<String?> Function() onRequestReset = () async =>
      'Un code vient de vous être envoyé.';
  Future<String?> Function() onResetPassword = () async =>
      'Mot de passe modifié.';

  int meCalls = 0;
  int refreshCalls = 0;
  int logoutCalls = 0;
  int loginCalls = 0;
  String? lastLoginEmail;
  String? lastLoginPassword;
  Map<String, String>? lastRegister;
  Map<String, String>? lastReset;
  final List<String> resetRequests = <String>[];

  Future<String?> Function() onChangePassword = () async =>
      'Mot de passe modifié avec succès.';
  Future<String?> Function() onDeleteAccount = () async =>
      'Compte supprimé avec succès.';
  Map<String, String>? lastPasswordChange;
  String? lastDeletePassword;

  @override
  Future<AppUser> me() {
    meCalls++;
    return onMe();
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    loginCalls++;
    lastLoginEmail = email;
    lastLoginPassword = password;
    return onLogin();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String fullName,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) {
    lastRegister = <String, String>{
      'email': email,
      'fullName': fullName,
      'username': username,
      'password': password,
      'passwordConfirmation': passwordConfirmation,
    };
    return onRegister();
  }

  @override
  Future<AuthSession> refresh() {
    refreshCalls++;
    return onRefresh();
  }

  @override
  Future<void> logout() {
    logoutCalls++;
    return onLogout();
  }

  @override
  Future<String?> requestPasswordReset(String email) {
    resetRequests.add(email);
    return onRequestReset();
  }

  @override
  Future<String?> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) {
    lastReset = <String, String>{
      'email': email,
      'otp': otp,
      'password': password,
      'passwordConfirmation': passwordConfirmation,
    };
    return onResetPassword();
  }

  @override
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) {
    lastPasswordChange = <String, String>{
      'current': currentPassword,
      'new': newPassword,
      'confirmation': confirmation,
    };
    return onChangePassword();
  }

  @override
  Future<String?> deleteAccount(String password) {
    lastDeletePassword = password;
    return onDeleteAccount();
  }
}

/// Adaptateur HTTP factice pour Dio : aucune vraie requête réseau.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

DioException connectionError(RequestOptions options) => DioException(
  requestOptions: options,
  type: DioExceptionType.connectionError,
);

// ---------------------------------------------------------------- Annonces

Paginated<T> pageOf<T>(List<T> items, {int page = 1, int last = 1}) =>
    Paginated<T>(
      items: items,
      currentPage: page,
      lastPage: last,
      total: items.length,
      perPage: items.length,
    );

ProductCard sampleCard({
  String id = 'p1',
  String slug = 'robe-wax',
  String title = 'Robe wax',
  double price = 15000,
  String type = 'product',
  bool liked = false,
  bool saved = false,
  int likes = 4,
  String? status,
}) => ProductCard.fromJson(<String, dynamic>{
  'id': id,
  'slug': slug,
  'title': title,
  'price': price,
  'currency': 'XOF',
  'type': type,
  'is_liked': liked,
  'is_saved': saved,
  'like_count': likes,
  if (status != null) 'status': status,
  'seller': <String, dynamic>{'id': 's1', 'full_name': 'Fatou Sow'},
});

ProductDetail sampleDetail({ProductCard? card}) {
  final product = card ?? sampleCard();
  return ProductDetail.fromJson(<String, dynamic>{
    'product': <String, dynamic>{
      'id': product.id,
      'slug': product.slug,
      'title': product.title,
      'price': product.price,
      'currency': 'XOF',
      'type': product.type,
      'description': 'Belle robe en pagne.',
      'condition': 'new',
      'is_negotiable': true,
      'like_count': product.likeCount,
      'category': <String, dynamic>{'id': 'c1', 'name': 'Mode'},
      'delivery_option': 'fixed',
      'delivery_fee': 1500,
    },
    'seller': <String, dynamic>{
      'id': 's1',
      'full_name': 'Fatou Sow',
      'username': 'fatou',
      'city': 'Dakar',
    },
    'is_liked': product.isLiked,
    'is_saved': product.isSaved,
  });
}

FavoriteEntry sampleFavorite(ProductCard card) =>
    FavoriteEntry(id: 'f-${card.id}', productId: card.id, product: card);

/// Faux dépôt d'annonces : chaque comportement est injecté par le test.
class FakeProductRepository implements ProductRepository {
  Future<Paginated<ProductCard>> Function(int page, FeedTab tab) onFeed =
      (page, tab) async => pageOf<ProductCard>(<ProductCard>[]);
  Future<Paginated<ProductCard>> Function(int page) onExplore = (page) async =>
      pageOf<ProductCard>(<ProductCard>[]);
  Future<SearchResults> Function(String query) onSearch = (query) async =>
      const SearchResults(
        products: <SearchProductHit>[],
        users: <SearchUserHit>[],
      );
  Future<ProductDetail> Function(String slug) onDetail = (slug) async =>
      sampleDetail();
  Future<List<Category>> Function() onCategories = () async => <Category>[];
  Future<LikeResult> Function(String id) onLike = (id) async =>
      const LikeResult(liked: true, likeCount: 5);
  Future<bool> Function(String id) onToggleSave = (id) async => true;

  Future<Paginated<ProductCard>> Function(int page) onMyProducts =
      (page) async => pageOf<ProductCard>(<ProductCard>[]);
  Future<void> Function(String id) onDeleteProduct = (id) async {};
  final List<String> deleted = <String>[];

  final List<String> viewed = <String>[];
  final List<FeedTab> feedTabs = <FeedTab>[];
  final List<Map<String, Object?>> exploreCalls = <Map<String, Object?>>[];

  @override
  Future<Paginated<ProductCard>> feed({
    int page = 1,
    int perPage = 10,
    FeedTab tab = FeedTab.forYou,
  }) {
    feedTabs.add(tab);
    return onFeed(page, tab);
  }

  @override
  Future<Paginated<ProductCard>> explore({
    int page = 1,
    int perPage = 20,
    String? query,
    String? categoryId,
    String? type,
    int? priceMin,
    int? priceMax,
    ExploreSort? sort,
  }) {
    exploreCalls.add(<String, Object?>{
      'page': page,
      'category': categoryId,
      'type': type,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'sort': sort,
    });
    return onExplore(page);
  }

  @override
  Future<SearchResults> search(String query) => onSearch(query);

  @override
  Future<ProductDetail> detail(String slug) => onDetail(slug);

  @override
  Future<List<Category>> categories() => onCategories();

  @override
  Future<LikeResult> like(String productId) => onLike(productId);

  @override
  Future<bool> toggleSave(String productId) => onToggleSave(productId);

  @override
  Future<void> recordView(String productId) async {
    viewed.add(productId);
  }

  @override
  Future<Paginated<ProductCard>> myProducts({int page = 1}) =>
      onMyProducts(page);

  @override
  Future<void> deleteProduct(String productId) async {
    deleted.add(productId);
    await onDeleteProduct(productId);
  }
}

class FakeFavoritesRepository implements FavoritesRepository {
  Future<Paginated<FavoriteEntry>> Function(int page) onList = (page) async =>
      pageOf<FavoriteEntry>(<FavoriteEntry>[]);
  int listCalls = 0;

  @override
  Future<Paginated<FavoriteEntry>> list({int page = 1}) {
    listCalls++;
    return onList(page);
  }
}

// ------------------------------------------------------- Profil et sécurité

AppUser fullUser({String? phone}) => AppUser.fromJson(<String, dynamic>{
  'id': 'u1',
  'email': 'awa@example.sn',
  'username': 'awa',
  'full_name': 'Awa Diop',
  'bio': 'Vendeuse de pagnes.',
  'website': 'https://awa.example.sn',
  'city': 'Dakar',
  'region': 'Dakar',
  'phone_number': phone,
  'email_verified_at': '2026-01-01T00:00:00.000000Z',
});

PublicProfile samplePublicProfile({
  bool following = false,
  String id = 'seller-1',
  String username = 'fatou',
}) => PublicProfile.fromJson(<String, dynamic>{
  'user': <String, dynamic>{
    'id': id,
    'username': username,
    'full_name': 'Fatou Sow',
    'city': 'Thiès',
    'bio': 'Mode et accessoires.',
    'is_premium': true,
  },
  'stats': <String, dynamic>{'products_count': 3, 'follower_count': 10},
  'badges': <Object?>[],
  'is_following': following,
});

class FakeProfileRepository implements ProfileRepository {
  Future<AppUser> Function() onMyProfile = () async => fullUser();
  Future<AppUser> Function() onUpdateProfile = () async => fullUser();
  Future<AppUser> Function(String? phone) onUpdatePhone = (phone) async =>
      fullUser(phone: phone);
  Future<PublicProfile> Function(String username) onPublicProfile =
      (username) async => samplePublicProfile(username: username);
  Future<Paginated<ProductCard>> Function(String username, int page)
  onSellerProducts = (username, page) async =>
      pageOf<ProductCard>(<ProductCard>[]);
  Future<FollowResult> Function(String id) onFollow = (id) async =>
      const FollowResult(following: true, isMutual: false);
  Future<FollowResult> Function(String id) onUnfollow = (id) async =>
      const FollowResult(following: false, isMutual: false);

  /// Champs envoyés lors du dernier `updateProfile` (seuls les champs non nuls).
  Map<String, String>? lastUpdate;
  String? lastPhone;
  bool phoneUpdated = false;
  final List<String> followed = <String>[];
  final List<String> unfollowed = <String>[];

  @override
  Future<AppUser> myProfile() => onMyProfile();

  @override
  Future<AppUser> updateProfile({
    String? fullName,
    String? username,
    String? email,
    String? bio,
    String? website,
    String? city,
    String? region,
    String? currentPassword,
  }) {
    lastUpdate = <String, String>{
      if (fullName != null) 'full_name': fullName,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (website != null) 'website': website,
      if (city != null) 'city': city,
      if (region != null) 'region': region,
      if (currentPassword != null) 'current_password': currentPassword,
    };
    return onUpdateProfile();
  }

  @override
  Future<AppUser> updatePhone(String? phoneNumber) {
    phoneUpdated = true;
    lastPhone = phoneNumber;
    return onUpdatePhone(phoneNumber);
  }

  @override
  Future<PublicProfile> publicProfile(String username) =>
      onPublicProfile(username);

  @override
  Future<Paginated<ProductCard>> sellerProducts(
    String username, {
    int page = 1,
  }) => onSellerProducts(username, page);

  @override
  Future<FollowResult> follow(String userId) {
    followed.add(userId);
    return onFollow(userId);
  }

  @override
  Future<FollowResult> unfollow(String userId) {
    unfollowed.add(userId);
    return onUnfollow(userId);
  }
}

class FakeSafetyRepository implements SafetyRepository {
  Future<String?> Function() onReportProduct = () async =>
      'Signalement envoyé. Merci pour votre vigilance.';
  Future<String?> Function() onReportUser = () async =>
      'Signalement envoyé. Notre équipe va examiner ce profil.';
  Future<String?> Function() onReportProblem = () async =>
      'Signalement reçu. Merci pour votre retour.';
  Future<String?> Function(String id) onBlock = (id) async =>
      'Utilisateur bloqué.';
  Future<String?> Function(String id) onUnblock = (id) async =>
      'Utilisateur débloqué.';
  Future<List<BlockedUser>> Function() onBlockedUsers = () async =>
      <BlockedUser>[];

  final List<String> reportedProducts = <String>[];
  final List<String> reportedUsers = <String>[];
  final List<String> blocked = <String>[];
  final List<String> unblocked = <String>[];
  ProductReportReason? lastProductReason;
  UserReportReason? lastUserReason;
  String? lastDescription;
  SupportCategory? lastSupportCategory;
  String? lastSupportDescription;

  @override
  Future<String?> reportProduct(
    String productId,
    ProductReportReason reason, {
    String? description,
  }) {
    reportedProducts.add(productId);
    lastProductReason = reason;
    lastDescription = description;
    return onReportProduct();
  }

  @override
  Future<String?> reportUser(
    String userId,
    UserReportReason reason, {
    String? description,
  }) {
    reportedUsers.add(userId);
    lastUserReason = reason;
    lastDescription = description;
    return onReportUser();
  }

  @override
  Future<String?> reportProblem(SupportCategory category, String description) {
    lastSupportCategory = category;
    lastSupportDescription = description;
    return onReportProblem();
  }

  @override
  Future<String?> blockUser(String userId) {
    blocked.add(userId);
    return onBlock(userId);
  }

  @override
  Future<String?> unblockUser(String userId) {
    unblocked.add(userId);
    return onUnblock(userId);
  }

  @override
  Future<List<BlockedUser>> blockedUsers() => onBlockedUsers();
}

// ----------------------------------------------------------- Notifications

AppNotification sampleNotification({
  String id = 'n1',
  String type = 'like',
  String title = 'Fatou a aimé votre annonce',
  String body = 'Robe wax',
  bool isRead = false,
  String? actionUrl,
}) => AppNotification.fromJson(<String, dynamic>{
  'id': id,
  'type': type,
  'title': title,
  'body': body,
  'is_read': isRead,
  'action_url': actionUrl,
  'created_at': '2026-10-19T11:00:00.000000Z',
});

NotificationDetail sampleNotificationDetail(
  String id, {
  String? actionUrl,
  bool canContest = false,
  String contestType = 'video',
  Map<String, dynamic>? appeal,
  String title = 'Votre vidéo a été retirée',
  String body = 'Elle ne respecte pas les règles.',
}) => NotificationDetail.fromJson(<String, dynamic>{
  'notification': <String, dynamic>{
    'id': id,
    'type': 'admin',
    'title': title,
    'body': body,
    'is_read': true,
    'action_url': actionUrl,
    'created_at': '2026-10-19T11:00:00.000000Z',
  },
  'contest': canContest || appeal != null
      ? <String, dynamic>{
          'type': contestType,
          'can_contest': canContest,
          'appeal': appeal,
        }
      : null,
});

NotificationPreference samplePreference({
  String type = 'like',
  String label = 'Mentions « j\'aime »',
  bool inApp = true,
  bool email = false,
  bool push = true,
}) => NotificationPreference(
  type: type,
  label: label,
  inAppEnabled: inApp,
  emailEnabled: email,
  pushEnabled: push,
);

class FakeNotificationRepository implements NotificationRepository {
  Future<Paginated<AppNotification>> Function(NotificationTab tab, int page)
  onList = (tab, page) async => pageOf<AppNotification>(<AppNotification>[]);
  Future<NotificationCounts> Function() onUnreadCount = () async =>
      const NotificationCounts();
  Future<NotificationDetail> Function(String id) onDetail = (id) async =>
      sampleNotificationDetail(id);
  Future<void> Function(String id) onMarkRead = (id) async {};
  Future<void> Function(String id) onDelete = (id) async {};
  Future<String?> Function(String id, String message) onContest =
      (id, message) async => "Votre message a été envoyé à l'équipe.";
  Future<List<NotificationPreference>> Function() onPreferences = () async =>
      <NotificationPreference>[];
  Future<void> Function(List<NotificationPreference> prefs)
  onUpdatePreferences = (prefs) async {};

  final List<NotificationTab> listedTabs = <NotificationTab>[];
  final List<String> markedRead = <String>[];
  final List<NotificationTab> markedAll = <NotificationTab>[];
  final List<String> deleted = <String>[];
  final Map<String, String> contested = <String, String>{};
  List<NotificationPreference>? lastPreferences;
  int unreadCalls = 0;

  @override
  Future<Paginated<AppNotification>> list({
    NotificationTab tab = NotificationTab.all,
    int page = 1,
  }) {
    listedTabs.add(tab);
    return onList(tab, page);
  }

  @override
  Future<NotificationCounts> unreadCount() {
    unreadCalls++;
    return onUnreadCount();
  }

  @override
  Future<NotificationDetail> detail(String id) => onDetail(id);

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
    await onMarkRead(id);
  }

  @override
  Future<void> markAllRead({NotificationTab tab = NotificationTab.all}) async {
    markedAll.add(tab);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    await onDelete(id);
  }

  @override
  Future<String?> contest(String id, String message) {
    contested[id] = message;
    return onContest(id, message);
  }

  @override
  Future<List<NotificationPreference>> preferences() => onPreferences();

  @override
  Future<void> updatePreferences(
    List<NotificationPreference> preferences,
  ) async {
    lastPreferences = preferences;
    await onUpdatePreferences(preferences);
  }
}

// ------------------------------------------------------ Premium et classements

const samplePlans = <PremiumPlan>[
  PremiumPlan(id: 'monthly', label: 'Mensuel', price: 2000, currency: 'XOF'),
  PremiumPlan(id: 'annual', label: 'Annuel', price: 20000, currency: 'XOF'),
];

class FakePremiumRepository implements PremiumRepository {
  Future<PublicConfig> Function() onConfig = () async => const PublicConfig(
    beta: true,
    listingFeeWithVideo: 0,
    premiumOfferSlots: 100,
    premiumPayments: false,
  );
  Future<List<PremiumPlan>> Function() onPlans = () async => samplePlans;
  Future<PremiumStatus> Function() onStatus = () async =>
      const PremiumStatus(isPremium: false);
  Future<PremiumOffer> Function() onOffer = () async =>
      const PremiumOffer(slotsTotal: 100, slotsLeft: 40, days: 90);
  Future<OfferApplyResult> Function()
  onApply = () async => const OfferApplyResult(
    myStatus: 'pending',
    message:
        "Candidature envoyée. Nous vous préviendrons dès qu'elle est examinée.",
  );
  Future<PaymentStart?> Function(String planId) onSubscribe = (planId) async =>
      PaymentStart(paymentUrl: Uri.parse('https://pay.example/session/abc'));

  final List<String> subscribed = <String>[];
  int applyCalls = 0;
  int statusCalls = 0;

  @override
  Future<PublicConfig> config() => onConfig();

  @override
  Future<List<PremiumPlan>> plans() => onPlans();

  @override
  Future<PremiumStatus> status() {
    statusCalls++;
    return onStatus();
  }

  @override
  Future<PremiumOffer> offer() => onOffer();

  @override
  Future<OfferApplyResult> applyOffer() {
    applyCalls++;
    return onApply();
  }

  @override
  Future<PaymentStart?> subscribe(
    String planId, {
    String paymentMethod = 'wave',
  }) {
    subscribed.add(planId);
    return onSubscribe(planId);
  }
}

RankingEntry rankingEntry({
  int rank = 1,
  String name = 'Fatou Sow',
  String? username = 'fatou',
  bool anonymous = false,
  Map<String, dynamic> metrics = const <String, dynamic>{},
}) => RankingEntry.fromJson(<String, dynamic>{
  'rank': rank,
  'anonymous': anonymous,
  'full_name': name,
  'username': username,
  ...metrics,
});

class FakeRankingRepository implements RankingRepository {
  Future<RankingPreferences> Function() onPreferences = () async =>
      const RankingPreferences(isPremium: true, optIn: true, anonymous: false);
  Future<RankingPreferences> Function(bool optIn, bool anonymous) onUpdate =
      (optIn, anonymous) async => RankingPreferences(
        isPremium: true,
        optIn: optIn,
        anonymous: anonymous,
      );
  Future<List<RankingEntry>> Function(RankingKind kind) onUsers =
      (kind) async => <RankingEntry>[];
  Future<List<ProductRankingEntry>> Function() onProducts = () async =>
      <ProductRankingEntry>[];

  final List<(bool, bool)> updates = <(bool, bool)>[];
  final List<RankingKind> requested = <RankingKind>[];

  @override
  Future<RankingPreferences> preferences() => onPreferences();

  @override
  Future<RankingPreferences> updatePreferences({
    required bool optIn,
    required bool anonymous,
  }) {
    updates.add((optIn, anonymous));
    return onUpdate(optIn, anonymous);
  }

  @override
  Future<List<RankingEntry>> users(RankingKind kind) {
    requested.add(kind);
    return onUsers(kind);
  }

  @override
  Future<List<ProductRankingEntry>> products() {
    requested.add(RankingKind.products);
    return onProducts();
  }
}

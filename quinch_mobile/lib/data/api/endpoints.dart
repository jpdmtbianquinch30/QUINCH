/// Chemins relatifs à `API_BASE_URL` (ex. https://api.quinch.sn/api/v1).
/// Chaque chemin a été lu dans backend/routes/api.php. Aucun n'est inventé.
abstract final class Endpoints {
  // Public
  static const publicConfig = 'public-config';
  static const feedConfig = 'feed/config';
  static const legalInfo = 'legal/info';
  static const categories = 'categories';

  // Auth
  static const login = 'auth/login';
  static const register = 'auth/register';
  static const forgotPassword = 'auth/forgot-password';
  static const resetPassword = 'auth/reset-password';
  static const google = 'auth/google';
  static const googleUpdateUsername = 'auth/google/update-username';
  static const me = 'auth/me';
  static const refresh = 'auth/refresh';
  static const logout = 'auth/logout';
  static const logoutAll = 'auth/logout-all';
  static const changePassword = 'auth/change-password'; // PUT
  static const deleteAccount = 'auth/delete-account'; // POST ou DELETE

  // Profil
  static const userProfile = 'user/profile'; // GET, PUT
  static const userPhone = 'user/phone'; // PUT
  static const userAvatar = 'user/upload-avatar';
  static const userCover = 'user/upload-cover';
  static const userPreferences = 'user/preferences';
  static const userPolicies = 'user/policies';
  static const exportData = 'users/export-data';
  static const supportReport = 'support/report';
  static const blockedUsers = 'users/blocked';
  static String publicProfile(String username) => 'users/$username/profile';
  static String sellerProducts(String username) => 'users/$username/products';
  static String blockUser(String id) => 'users/$id/block';
  static String unblockUser(String id) => 'users/$id/unblock';
  static String follow(String id) => 'follow/$id';
  static String unfollow(String id) => 'unfollow/$id';
  static String reportUser(String id) => 'users/$id/report';

  // Produits
  static const feed = 'products/feed';
  static const explorer = 'products';
  static const createProduct = 'products'; // POST multipart
  static const myProducts = 'my-products';
  static const search = 'search';
  static const searchSuggestions = 'search/suggestions';
  static const searchTrending = 'search/trending';
  static const uploadVideo = 'products/upload-video';
  static String product(String slug) => 'products/$slug'; // GET (slug)
  static String productById(String id) => 'products/$id'; // PUT, DELETE (id)
  static String publish(String id) => 'products/$id/publish';
  static String like(String id) => 'products/$id/like';
  static String save(String id) => 'products/$id/save';
  static String view(String id) => 'products/$id/view';
  static String reportProduct(String id) => 'products/$id/report';

  // Sondes de disponibilité (GET sans identifiant de ressource)
  static const negotiations = 'negotiations';
  static const myFollowers = 'my-followers';
  static const badgesDefinitions = 'badges/definitions';
  static const favoritesCollections = 'favorites/collections';

  // Favoris
  static const favorites = 'favorites';
  static const favoritesToggle = 'favorites/toggle';
  static const favoritesCount = 'favorites/count';

  // Messagerie
  static const conversations = 'conversations';
  static const conversationStart = 'conversations/start';
  static const conversationsBulkDelete = 'conversations/bulk-delete';
  static String conversation(String id) => 'conversations/$id';
  static String conversationMessages(String id) => 'conversations/$id/messages';
  static String conversationSince(String id) =>
      'conversations/$id/messages/since'; // ?after=
  static String conversationFile(String id) => 'conversations/$id/file';

  // Notifications
  static const notifications =
      'notifications'; // ?tab=all|interactions|messages|system
  static const notificationsUnreadCount = 'notifications/unread-count';
  static const notificationsReadAll = 'notifications/read-all';
  static const notificationsPreferences = 'notifications/preferences';
  static const announcements = 'notifications/announcements';
  static String notification(String id) => 'notifications/$id';
  static String notificationRead(String id) => 'notifications/$id/read';
  static String notificationUnread(String id) => 'notifications/$id/unread';
  static String notificationContest(String id) => 'notifications/$id/contest';

  // Premium et classements
  static const premiumPlans = 'premium/plans';
  static const premiumStatus = 'premium/status';
  static const premiumOffer = 'premium/offer';
  static const premiumOfferApply = 'premium/offer/apply';
  static const premiumSubscribe = 'premium/subscribe';
  static const rankingSellers = 'rankings/sellers';
  static const rankingProducts = 'rankings/products';
  static const rankingProfiles = 'rankings/profiles';
  static const rankingFollowers = 'rankings/followers';
  static const rankingPreferences = 'rankings/preferences'; // GET, PATCH
}

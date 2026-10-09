<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\WaveWebhookController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProductVideoController;
use App\Http\Controllers\Api\V1\ProductFeedController;
use App\Http\Controllers\Api\V1\ProductInteractionController;
use App\Http\Controllers\Api\V1\TransactionController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\CartController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\FavoriteController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\NegotiationController;
use App\Http\Controllers\Api\V1\ShareController;
use App\Http\Controllers\Api\V1\FollowController;
use App\Http\Controllers\Api\V1\BadgeController;
use App\Http\Controllers\Api\V1\RankingController;
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\PublicProfileController;
use App\Http\Controllers\Api\V1\AdminController;
use App\Http\Controllers\Api\V1\AdminUserController;
use App\Http\Controllers\Api\V1\ContentModerationController;
use App\Http\Controllers\Api\V1\SecurityController;
use App\Http\Controllers\Api\V1\VideoStreamController;
use App\Http\Controllers\Api\V1\MarketplaceController;
use App\Http\Controllers\Api\V1\GoogleAuthController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\LegalController;
use App\Http\Controllers\Api\V1\PremiumController;
use App\Http\Controllers\Api\V1\AdminProductController;
use App\Http\Controllers\Api\V1\AdminTransactionController;
use App\Http\Controllers\Api\V1\AdminSettingsController;
use App\Http\Controllers\Api\V1\AdminStaffController;
use App\Http\Controllers\Api\V1\AdminPremiumController;
use App\Http\Controllers\Api\V1\AdminReviewController;
use App\Http\Controllers\Api\V1\ModerationAppealController;
use App\Http\Controllers\Api\V1\AdminBadgeController;
/*
|--------------------------------------------------------------------------
| QUINCH API Routes v1 - Complete Architecture
|--------------------------------------------------------------------------
*/

// ─── Auth ────────────────────────────────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:3,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:5,1');
    Route::post('forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::post('reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:5,1');

    // Connexion / inscription via Google : route PUBLIQUE par définition.
    // (Avant ce correctif elle était déclarée à l'intérieur du groupe
    // `auth:sanctum` — il fallait donc déjà être connecté pour pouvoir se
    // connecter, ce qui renvoyait systématiquement 401.)
    Route::post('google', [GoogleAuthController::class, 'handleToken'])->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::post('logout-all', [AuthController::class, 'logoutAll']);
        Route::post('refresh', [AuthController::class, 'refresh']);
        Route::get('me', [AuthController::class, 'me']);
        Route::put('change-password', [AuthController::class, 'changePassword']);
        Route::delete('delete-account', [AuthController::class, 'deleteAccount']);
        Route::post('delete-account', [AuthController::class, 'deleteAccount'])->middleware('throttle:5,1');
    });
});

// ─── Video Streaming (public — no auth required) ────────────────────────────
Route::get('videos/{videoId}/stream', [VideoStreamController::class, 'stream'])
    ->where('videoId', '[a-f0-9\-]{36}')->name('videos.stream');
Route::get('videos/{videoId}/thumbnail', [VideoStreamController::class, 'thumbnail'])
    ->where('videoId', '[a-f0-9\-]{36}')->name('videos.thumbnail');
Route::get('videos/stream-path', [VideoStreamController::class, 'streamByPath']);

// ─── Public ──────────────────────────────────────────────────────────────────
// Mentions légales : éditeur, contact, hébergeur, versions des textes.
Route::get('legal/info', [LegalController::class, 'info'])->middleware('throttle:60,1');
// Supervision : santé détaillée, protégée par le jeton HEALTH_TOKEN (404 sinon).
Route::get('ops/health', [HealthController::class, 'show'])->middleware('throttle:30,1');
// Bannières, message défilant et mode maintenance pilotés depuis l'admin.
Route::get('feed/config', [AdminSettingsController::class, 'publicFeedConfig']);
Route::get('categories', [CategoryController::class, 'index']);
Route::get('products', [MarketplaceController::class, 'index']);
Route::get('products/feed', [ProductFeedController::class, 'index']);
Route::get('products/active-sellers', [ProductFeedController::class, 'activeSellers']);
Route::get('search', [ProductFeedController::class, 'search']);
Route::get('search/suggestions', [ProductFeedController::class, 'suggestions']);
Route::get('search/trending', [ProductFeedController::class, 'trending']);
// Compteur de vues : purement analytique (n'utilise même pas $request->user()
// dans ProductInteractionController::view), n'a donc aucune raison d'exiger
// une connexion. Cette route traînait par erreur dans le groupe
// auth:sanctum plus bas : n'importe quelle visite de page produit sans
// token valide (session pas encore chargée, token expiré, visiteur anonyme)
// recevait un 401 sur cet appel silencieux, ce que l'intercepteur front
// interprétait comme "session invalide" et déconnectait tout le monde -
// y compris en plein milieu d'un parcours d'achat ou d'abonnement Premium
// n'ayant pourtant aucun rapport avec cette route.
Route::post('products/{product}/view', [ProductInteractionController::class, 'view']);
Route::get('products/{product:slug}', [ProductController::class, 'show']);
Route::middleware('feature:sharing')->group(function () {
    Route::post('shares/track', [ShareController::class, 'track'])->middleware('throttle:100,1');
    Route::get('products/{product:slug}/share-data', [ShareController::class, 'getShareData']);
});

// Public profiles
Route::get('users/{username}/profile', [PublicProfileController::class, 'show']);
Route::get('users/{username}/products', [PublicProfileController::class, 'products']);
Route::middleware('feature:reviews')->group(function () {
    Route::get('users/{user}/reviews', [ReviewController::class, 'sellerReviews']);
});
Route::middleware('feature:badges')->group(function () {
    Route::get('users/{user}/badges', [BadgeController::class, 'userBadges']);
    Route::get('badges/definitions', [BadgeController::class, 'allBadgeDefinitions']);
});
Route::middleware('feature:follow')->group(function () {
    Route::get('users/{user}/followers', [FollowController::class, 'followers']);
    Route::get('users/{user}/following', [FollowController::class, 'following']);
    Route::get('users/{user}/follow-counts', [FollowController::class, 'counts']);
});

// Google auth — choix du pseudo après la première connexion.
Route::middleware('auth:sanctum')->group(function () {
    Route::post('auth/google/update-username', [GoogleAuthController::class, 'updateUsername'])->middleware('throttle:10,1');
});

// ─── Authenticated ────────────────────────────────────────────────────────────
Route::middleware(['auth:sanctum'])->group(function () {

    // User profile
    Route::prefix('user')->group(function () {
        Route::get('profile', [UserController::class, 'profile']);
        Route::put('profile', [UserController::class, 'updateProfile']);
        Route::post('preferences', [UserController::class, 'savePreferences']);
        Route::post('policies', [UserController::class, 'savePolicies']);
        Route::post('upload-avatar', [UserController::class, 'uploadAvatar']);
        Route::post('upload-cover', [UserController::class, 'uploadCover']);
        Route::put('phone', [UserController::class, 'updatePhone'])->middleware('throttle:10,1');
    });

    // Blocked users management
    Route::get('users/blocked', [UserController::class, 'blockedUsers']);
    Route::post('users/{user}/block', [UserController::class, 'blockUser']);
    Route::post('users/{user}/unblock', [UserController::class, 'unblockUser']);
    Route::get('users/export-data', [UserController::class, 'exportData'])->middleware('throttle:5,60');

    // Contester un retrait de vidéo / d'annonce
    Route::get('moderation/appeals/mine', [ModerationAppealController::class, 'mine']);
    Route::post('moderation/appeals', [ModerationAppealController::class, 'store'])->middleware('throttle:5,1');

    // Support
    Route::post('support/report', [UserController::class, 'reportProblem']);

    // Report user
    Route::post('users/{user}/report', [UserController::class, 'reportUser'])->middleware('throttle:5,1');

    // Products CRUD
    Route::prefix('products')->group(function () {
        Route::post('upload-video', [ProductVideoController::class, 'upload'])->middleware('throttle:5,1');
        Route::post('/', [ProductController::class, 'store']);
        Route::put('{product}', [ProductController::class, 'update']);
        Route::delete('{product}', [ProductController::class, 'destroy']);
        Route::post('{product}/like', [ProductInteractionController::class, 'toggleLike']);
        Route::post('{product}/share', [ProductInteractionController::class, 'share']);
        Route::post('{product}/save', [ProductInteractionController::class, 'toggleSave']);
        Route::post('{product}/report', [ProductInteractionController::class, 'report'])->middleware('throttle:5,1');
                Route::post('{product}/publish', [ProductController::class, 'publish'])->middleware('throttle:5,1');
    });
    Route::get('my-products', [ProductController::class, 'myProducts']);
    Route::get('my-likes', [ProductInteractionController::class, 'myLikes']);

    // Cart
        Route::prefix('cart')->middleware('feature:purchases')->group(function () {
        Route::get('/', [CartController::class, 'index']);
        Route::post('add', [CartController::class, 'add']);
        Route::put('{cartItem}', [CartController::class, 'update']);
        Route::delete('{cartItem}', [CartController::class, 'remove']);
        Route::delete('/', [CartController::class, 'clear']);
        Route::get('count', [CartController::class, 'count']);
    });

    // Chat
    Route::prefix('conversations')->group(function () {
        Route::get('/', [ConversationController::class, 'index']);
        Route::post('start', [ConversationController::class, 'start']);
        Route::post('bulk-delete', [ConversationController::class, 'bulkDestroy']);
        Route::get('{conversation}', [ConversationController::class, 'show']);
        Route::get('{conversation}/messages/since', [ConversationController::class, 'newMessages']);
        Route::post('{conversation}/messages', [ConversationController::class, 'sendMessage']);
        Route::post('{conversation}/audio', [ConversationController::class, 'sendAudio'])->middleware('feature:chat_audio');
        Route::post('{conversation}/file', [ConversationController::class, 'sendFile']);
        Route::post('{conversation}/tags', [ConversationController::class, 'tagProduct']);
        Route::post('{conversation}/messages/{message}/availability', [ConversationController::class, 'respondAvailability']);
         Route::delete('{conversation}', [ConversationController::class, 'destroy']);
         Route::delete('{conversation}/messages/{message}', [ConversationController::class, 'deleteMessage']);

    });

    // Favorites
    Route::prefix('favorites')->group(function () {
        Route::get('/', [FavoriteController::class, 'index']);
        Route::post('toggle', [FavoriteController::class, 'toggle']);
        Route::get('count', [FavoriteController::class, 'count']);
        Route::middleware('feature:favorites_collections')->group(function () {
            Route::get('collections', [FavoriteController::class, 'collections']);
            Route::post('collections', [FavoriteController::class, 'createCollection']);
        });
    });

    // Notifications
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('unread-count', [NotificationController::class, 'unreadCount']);
        Route::get('announcements', [NotificationController::class, 'announcements']);
        Route::get('{notification}', [NotificationController::class, 'show'])->whereUuid('notification');
        Route::post('{notification}/read', [NotificationController::class, 'markRead']);
        Route::post('{notification}/unread', [NotificationController::class, 'markUnread'])->whereUuid('notification');
        Route::post('{notification}/contest', [NotificationController::class, 'contest'])->middleware('throttle:5,1')->whereUuid('notification');
        Route::post('read-all', [NotificationController::class, 'markAllRead']);
        Route::delete('{notification}', [NotificationController::class, 'destroy']);
        Route::get('preferences', [NotificationController::class, 'getPreferences']);
        Route::put('preferences', [NotificationController::class, 'updatePreferences']);
    });

    // Negotiations (V2 — désactivé en V1)
    Route::prefix('negotiations')->middleware('feature:negotiation')->group(function () {
        Route::get('/', [NegotiationController::class, 'myNegotiations']);
        Route::post('propose', [NegotiationController::class, 'propose']);
        Route::post('{negotiation}/respond', [NegotiationController::class, 'respond']);
    });

        // Transactions
        Route::prefix('transactions')->middleware('feature:purchases')->group(function () {
        Route::post('initiate', [TransactionController::class, 'initiate'])->middleware('throttle:3,1');
        Route::get('history', [TransactionController::class, 'history']);
        Route::get('{transaction}', [TransactionController::class, 'show']);
        Route::put('{transaction}/status', [TransactionController::class, 'updateStatus']);
        Route::post('{transaction}/dispute', [TransactionController::class, 'dispute']);
        Route::post('{transaction}/cancel', [TransactionController::class, 'cancelPayment']);
        });

            // Premium (abonnement vendeur)
    Route::prefix('premium')->group(function () {
        Route::get('plans', [PremiumController::class, 'plans']);
        Route::post('subscribe', [PremiumController::class, 'subscribe'])->middleware('throttle:3,1');
        Route::get('status', [PremiumController::class, 'status']);
    });

    // Classements — reserves aux comptes Premium (voir RankingController).
    Route::prefix('rankings')->group(function () {
        Route::get('sellers', [RankingController::class, 'sellers']);
        Route::get('products', [RankingController::class, 'products']);
        Route::get('profiles', [RankingController::class, 'profiles']);
        Route::get('followers', [RankingController::class, 'followers']);
        Route::get('preferences', [RankingController::class, 'myPreferences']);
        Route::patch('preferences', [RankingController::class, 'updatePreferences']);
    });

    // Follows & Friends (V2 — désactivé en V1)
    Route::middleware('feature:follow')->group(function () {
        Route::post('follow/{user}', [FollowController::class, 'follow']);
        Route::delete('unfollow/{user}', [FollowController::class, 'unfollow']);
        Route::get('my-followers', [FollowController::class, 'myFollowers']);
        Route::get('my-following', [FollowController::class, 'myFollowing']);
        Route::get('my-friends', [FollowController::class, 'friends']);
        Route::get('users/{user}/is-friend', [FollowController::class, 'isFriend']);
        Route::get('products/friends-feed', [ProductFeedController::class, 'friendsFeed']);
    });

    // Badges (V2 — désactivé en V1)
    Route::middleware('feature:badges')->group(function () {
        Route::get('my-badges', [BadgeController::class, 'myBadges']);
        Route::get('my-customers', [BadgeController::class, 'myCustomers']);
        Route::post('users/{user}/loyalty-badge', [BadgeController::class, 'sellerAward']);
        Route::delete('users/{user}/loyalty-badge', [BadgeController::class, 'sellerRevoke']);
    });

    // Reviews (V2 — désactivé en V1)
    Route::middleware('feature:reviews')->group(function () {
        Route::post('reviews', [ReviewController::class, 'create']);
        Route::post('reviews/{review}/respond', [ReviewController::class, 'respond']);
    });
});

// ─── Admin ───────────────────────────────────────────────────────────────────
// Accès : moderator, admin, super_admin. Chaque route déclare la permission
// FINE requise (config/permissions.php). Les actions destructrices ou
// sensibles exigent en plus le mot de passe de l'admin (middleware `sensitive` :
// champ `admin_password` ou en-tête X-Admin-Password).
Route::prefix('admin')
    ->middleware(['auth:sanctum', 'role:moderator,admin,super_admin'])
    ->group(function () {
        Route::get('me', [AdminController::class, 'me']);

        // Dashboard
        Route::get('dashboard/metrics', [AdminController::class, 'metrics']);
        Route::get('dashboard/real-time', [AdminController::class, 'realTime']);

        // Boîte unique « À traiter »
        Route::get('inbox', [ContentModerationController::class, 'inbox'])->middleware('permission:reports.handle');

        // ── Utilisateurs ──
        Route::get('users', [AdminUserController::class, 'index'])->middleware('permission:users.view');
        Route::get('users/{user}', [AdminUserController::class, 'show'])->middleware('permission:users.view');
        Route::post('users/{user}/suspend', [AdminUserController::class, 'suspend'])->middleware('permission:users.suspend,users.suspend_short');
        Route::post('users/{user}/activate', [AdminUserController::class, 'activate'])->middleware('permission:users.suspend,users.suspend_short');
        Route::post('users/{user}/warn', [AdminUserController::class, 'warn'])->middleware('permission:users.warn');
        Route::delete('users/{user}/strikes/{strike}', [AdminUserController::class, 'revokeStrike'])->middleware('permission:users.warn');
        Route::post('users/{user}/ban', [AdminUserController::class, 'ban'])->middleware(['permission:users.ban', 'sensitive']);
        Route::post('users/{user}/unban', [AdminUserController::class, 'unban'])->middleware(['permission:users.ban', 'sensitive']);
        Route::post('users/{user}/verify-kyc', [AdminUserController::class, 'verifyKyc'])->middleware('permission:users.kyc');
        Route::post('users/{user}/adjust-trust', [AdminUserController::class, 'adjustTrust'])->middleware('permission:users.trust');
        Route::post('users/{user}/send-notification', [AdminUserController::class, 'sendNotification'])->middleware('permission:users.notify');
        Route::delete('users/{user}', [AdminUserController::class, 'destroy'])->middleware(['permission:users.delete', 'sensitive']);
        Route::post('users/{user}/delete', [AdminUserController::class, 'destroy'])->middleware(['permission:users.delete', 'sensitive']);
        Route::post('users/{user}/export', [AdminUserController::class, 'export'])->middleware(['permission:users.export', 'sensitive']);
        Route::post('users/{user}/role', [AdminStaffController::class, 'setRole'])->middleware(['permission:staff.manage', 'sensitive']);
        Route::post('users/{user}/premium/grant', [AdminPremiumController::class, 'grant'])->middleware('permission:premium.manage');
        Route::post('users/{user}/premium/revoke', [AdminPremiumController::class, 'revoke'])->middleware('permission:premium.manage');

        // Badges (admin)
        Route::post('users/{user}/badges', [BadgeController::class, 'award'])->middleware('permission:users.badges');
        Route::delete('users/{user}/badges/{badgeType}', [BadgeController::class, 'revoke'])->middleware('permission:users.badges');

        // Catalogue de badges (création, règles automatiques, zones d'affichage)
        Route::get('badges', [AdminBadgeController::class, 'index'])->middleware('permission:badges.manage');
        Route::post('badges', [AdminBadgeController::class, 'store'])->middleware('permission:badges.manage');
        Route::post('badges/sync', [AdminBadgeController::class, 'sync'])->middleware('permission:badges.manage');
        Route::put('badges/{badge}', [AdminBadgeController::class, 'update'])->middleware('permission:badges.manage');
        Route::delete('badges/{badge}', [AdminBadgeController::class, 'destroy'])->middleware('permission:badges.manage');
        Route::get('badges/{badge}/holders', [AdminBadgeController::class, 'holders'])->middleware('permission:badges.manage');

        // Équipe
        Route::get('staff', [AdminStaffController::class, 'index'])->middleware('permission:staff.manage');
        Route::post('staff', [AdminStaffController::class, 'store'])->middleware(['permission:staff.manage', 'sensitive']);
        Route::post('staff/{user}/password', [AdminStaffController::class, 'resetPassword'])->middleware(['permission:staff.manage', 'sensitive']);

        // ── Produits ──
        Route::get('products', [AdminProductController::class, 'index'])->middleware('permission:products.view');
        Route::post('products/bulk', [AdminProductController::class, 'bulk'])->middleware('permission:products.moderate');
        Route::get('products/{product}', [AdminProductController::class, 'show'])->middleware('permission:products.view');
        Route::post('products/{product}/hide', [AdminProductController::class, 'hide'])->middleware('permission:products.moderate');
        Route::post('products/{product}/restore', [AdminProductController::class, 'restore'])->middleware('permission:products.moderate');
        Route::post('products/{product}/delete', [AdminProductController::class, 'destroy'])->middleware('permission:products.moderate');
        Route::put('products/{product}', [AdminProductController::class, 'update'])->middleware('permission:products.edit_content');
        Route::post('products/{product}/force-status', [AdminProductController::class, 'forceStatus'])->middleware('permission:products.force_status');
        Route::post('products/{product}/pin', [AdminProductController::class, 'pin'])->middleware('permission:products.pin');
        Route::post('products/{product}/media/remove', [AdminProductController::class, 'removeImage'])->middleware('permission:media.remove');
        Route::post('products/{product}/media/replace', [AdminProductController::class, 'replaceImage'])->middleware('permission:media.remove');
        Route::post('products/{product}/video/remove', [AdminProductController::class, 'removeVideo'])->middleware('permission:media.remove');

        // ── Catégories ──
        Route::get('categories', [CategoryController::class, 'adminIndex'])->middleware('permission:categories.manage');
        Route::post('categories/reorder', [CategoryController::class, 'reorder'])->middleware('permission:categories.manage');
        Route::post('categories', [CategoryController::class, 'store'])->middleware('permission:categories.manage');
        Route::put('categories/{category}', [CategoryController::class, 'update'])->middleware('permission:categories.manage');
        Route::delete('categories/{category}', [CategoryController::class, 'destroy'])->middleware('permission:categories.manage');

        // ── Modération vidéo + contestations ──
        Route::get('moderation/pending', [ContentModerationController::class, 'pending'])->middleware('permission:videos.moderate');
        Route::get('moderation/reasons', [ContentModerationController::class, 'reasons'])->middleware('permission:videos.moderate');
        Route::post('moderation/bulk-action', [ContentModerationController::class, 'bulkAction'])->middleware('permission:videos.moderate');
        Route::post('videos/{video}/moderate', [ContentModerationController::class, 'moderate'])->middleware('permission:videos.moderate');
        Route::get('moderation/appeals', [ContentModerationController::class, 'appeals'])->middleware('permission:appeals.handle');
        Route::post('moderation/appeals/{appeal}/handle', [ContentModerationController::class, 'handleAppeal'])->middleware('permission:appeals.handle');

        // ── Signalements, tickets ──
        Route::get('reports/products', [ContentModerationController::class, 'productReports'])->middleware('permission:reports.handle');
        Route::post('reports/products/{report}/resolve', [ContentModerationController::class, 'resolveProductReport'])->middleware('permission:reports.handle');
        Route::get('reports/reported-users', [ContentModerationController::class, 'userReports'])->middleware('permission:reports.handle');
        Route::post('reports/reported-users/{report}/resolve', [ContentModerationController::class, 'resolveUserReport'])->middleware('permission:reports.handle');
        Route::get('reports/support-tickets', [ContentModerationController::class, 'supportTickets'])->middleware('permission:reports.handle');
        Route::post('reports/support-tickets/{ticket}/resolve', [ContentModerationController::class, 'resolveSupportTicket'])->middleware('permission:reports.handle');
        Route::post('reports/assign/{type}/{id}', [ContentModerationController::class, 'assign'])->middleware('permission:reports.handle');

        // ── Fraude ──
        Route::get('reports/fraud', [AdminController::class, 'fraudReport'])->middleware('permission:fraud.handle');
        Route::post('reports/fraud/scan', [AdminController::class, 'runFraudScan'])->middleware('permission:fraud.handle');
        Route::post('reports/fraud/{fraudDetection}/resolve', [AdminController::class, 'resolveFraud'])->middleware('permission:fraud.handle');

        // ── Transactions, litiges, finance ──
        Route::get('transactions', [AdminTransactionController::class, 'index'])->middleware('permission:finance.view');
        Route::get('transactions/export', [AdminTransactionController::class, 'export'])->middleware('permission:finance.view');
        Route::get('transactions/{transaction}', [AdminTransactionController::class, 'show'])->middleware('permission:finance.view');
        Route::get('transactions/{transaction}/conversation', [AdminTransactionController::class, 'conversation'])->middleware('permission:disputes.resolve');
        Route::post('transactions/{transaction}/resolve-dispute', [AdminTransactionController::class, 'resolveDispute'])->middleware(['permission:disputes.resolve', 'sensitive']);
        Route::get('reports/transactions', [AdminController::class, 'transactionReport'])->middleware('permission:finance.view');
        Route::get('reports/finance', [AdminController::class, 'financeReport'])->middleware('permission:finance.view');
        Route::get('reports/users', [AdminController::class, 'userReport'])->middleware('permission:audit.view');
        Route::get('reports/overview', [AdminController::class, 'overviewReport'])->middleware('permission:audit.view');

        // ── Premium, avis ──
        Route::get('premium', [AdminPremiumController::class, 'index'])->middleware('permission:premium.manage');
        Route::get('reviews', [AdminReviewController::class, 'index'])->middleware('permission:reviews.moderate');
        Route::delete('reviews/{review}', [AdminReviewController::class, 'destroy'])->middleware('permission:reviews.moderate');
        Route::post('reviews/{review}/delete', [AdminReviewController::class, 'destroy'])->middleware('permission:reviews.moderate');

        // ── Sécurité & journaux ──
        Route::get('security/alerts', [SecurityController::class, 'alerts'])->middleware('permission:fraud.handle');
        Route::get('security/logs', [SecurityController::class, 'logs'])->middleware('permission:audit.view');
        Route::get('security/admin-logs', [SecurityController::class, 'adminLogs'])->middleware('permission:audit.view');
        Route::get('security/admin-logs/export', [SecurityController::class, 'exportAdminLogs'])->middleware('permission:audit.view');
        Route::post('security/ip-ban', [SecurityController::class, 'banIp'])->middleware(['permission:security.ip_ban', 'sensitive']);
        Route::get('security/banned-ips', [SecurityController::class, 'bannedIps'])->middleware('permission:security.ip_ban');
        Route::delete('security/banned-ips/{bannedIp}', [SecurityController::class, 'unbanIp'])->middleware(['permission:security.ip_ban', 'sensitive']);
        Route::post('security/banned-ips/{bannedIp}/remove', [SecurityController::class, 'unbanIp'])->middleware(['permission:security.ip_ban', 'sensitive']);

        // ── Réglages, bannières du feed, notifications de masse ──
        Route::get('settings', [AdminSettingsController::class, 'index']);
        Route::put('settings', [AdminSettingsController::class, 'update'])->middleware('permission:feed.manage,notifications.broadcast');
        Route::put('settings/system', [AdminSettingsController::class, 'updateSystem'])->middleware(['permission:settings.manage', 'sensitive']);
        Route::get('feed/banners', [AdminSettingsController::class, 'banners'])->middleware('permission:feed.manage');
        Route::post('feed/banners', [AdminSettingsController::class, 'storeBanner'])->middleware('permission:feed.manage');
        Route::post('feed/banners/{banner}', [AdminSettingsController::class, 'updateBanner'])->middleware('permission:feed.manage');
        Route::delete('feed/banners/{banner}', [AdminSettingsController::class, 'destroyBanner'])->middleware('permission:feed.manage');
        Route::post('notifications/broadcast/count', [AdminSettingsController::class, 'countAudience'])->middleware('permission:notifications.broadcast');
        Route::post('notifications/broadcast', [AdminSettingsController::class, 'broadcast'])->middleware(['permission:notifications.broadcast', 'sensitive']);
        Route::get('notifications/broadcast-history', [AdminSettingsController::class, 'broadcastHistory'])->middleware('permission:notifications.broadcast');

        // System — reset/delete-all-videos : commandes Artisan uniquement
        // (quinch:reset-data / quinch:delete-all-videos), jamais en HTTP.
    });

// ─── Webhooks ────────────────────────────────────────────────────────────────
Route::prefix('webhooks')->group(function () {
    Route::post('orange-money', [TransactionController::class, 'webhookOrangeMoney']);
    // URL UNIQUE à enregistrer dans le portail Wave Business : aiguille selon client_reference.
    Route::post('wave', [WaveWebhookController::class, 'handle']);
    Route::post('wave-premium', [PremiumController::class, 'webhookWave']);
    Route::post('wave-listing', [ProductController::class, 'webhookWaveListingFee']);
});

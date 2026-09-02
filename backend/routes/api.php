<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
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
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\PublicProfileController;
use App\Http\Controllers\Api\V1\AdminController;
use App\Http\Controllers\Api\V1\AdminUserController;
use App\Http\Controllers\Api\V1\ContentModerationController;
use App\Http\Controllers\Api\V1\SecurityController;
use App\Http\Controllers\Api\V1\VideoStreamController;
use App\Http\Controllers\Api\V1\MarketplaceController;
use App\Http\Controllers\Api\V1\GoogleAuthController;
use App\Http\Controllers\Api\V1\PremiumController;
/*
|--------------------------------------------------------------------------
| QUINCH API Routes v1 - Complete Architecture
|--------------------------------------------------------------------------
*/

// ─── Auth ────────────────────────────────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:3,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:5,1');
    Route::post('verify-otp', [AuthController::class, 'verifyOtp'])->middleware('throttle:5,1');
    Route::post('forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::post('reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:5,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::post('logout-all', [AuthController::class, 'logoutAll']);
        Route::post('refresh', [AuthController::class, 'refresh']);
        Route::get('me', [AuthController::class, 'me']);
        Route::put('change-password', [AuthController::class, 'changePassword']);
        Route::delete('delete-account', [AuthController::class, 'deleteAccount']);
    });
});

// ─── Video Streaming (public — no auth required) ────────────────────────────
Route::get('videos/{videoId}/stream', [VideoStreamController::class, 'stream'])
    ->where('videoId', '[a-f0-9\-]{36}');
Route::get('videos/{videoId}/thumbnail', [VideoStreamController::class, 'thumbnail'])
    ->where('videoId', '[a-f0-9\-]{36}');
Route::get('videos/stream-path', [VideoStreamController::class, 'streamByPath']);

// ─── Public ──────────────────────────────────────────────────────────────────
Route::get('categories', [CategoryController::class, 'index']);
Route::get('products', [MarketplaceController::class, 'index']);
Route::get('products/feed', [ProductFeedController::class, 'index']);
Route::get('products/active-sellers', [ProductFeedController::class, 'activeSellers']);
Route::get('search', [ProductFeedController::class, 'search']);
Route::get('search/suggestions', [ProductFeedController::class, 'suggestions']);
Route::get('search/trending', [ProductFeedController::class, 'trending']);
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

// ─── Authenticated ───────────────────────────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // User profile
    Route::prefix('user')->group(function () {
        Route::get('profile', [UserController::class, 'profile']);
        Route::put('profile', [UserController::class, 'updateProfile']);
        Route::post('preferences', [UserController::class, 'savePreferences']);
        Route::post('upload-avatar', [UserController::class, 'uploadAvatar']);
        Route::post('upload-cover', [UserController::class, 'uploadCover']);
        Route::post('phone/request-change', [UserController::class, 'requestPhoneChange'])->middleware('throttle:5,1');
        Route::post('phone/confirm-change', [UserController::class, 'confirmPhoneChange'])->middleware('throttle:5,1');
    });

    // Blocked users management
    Route::get('users/blocked', [UserController::class, 'blockedUsers']);
    Route::post('users/{user}/block', [UserController::class, 'blockUser']);
    Route::post('users/{user}/unblock', [UserController::class, 'unblockUser']);
    Route::get('users/export-data', [UserController::class, 'exportData']);

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
        Route::post('{product}/view', [ProductInteractionController::class, 'view']);
        Route::post('{product}/like', [ProductInteractionController::class, 'toggleLike']);
        Route::post('{product}/share', [ProductInteractionController::class, 'share']);
        Route::post('{product}/save', [ProductInteractionController::class, 'toggleSave']);
        Route::post('{product}/report', [ProductInteractionController::class, 'report'])->middleware('throttle:5,1');
    });
    Route::get('my-products', [ProductController::class, 'myProducts']);
    Route::get('my-likes', [ProductInteractionController::class, 'myLikes']);

    //google auth
    Route::post('auth/google', [GoogleAuthController::class, 'handleToken']);
Route::middleware('auth:sanctum')->group(function () {
    Route::post('auth/google/add-phone', [GoogleAuthController::class, 'addPhone']);
    Route::post('auth/google/update-username', [GoogleAuthController::class, 'updateUsername']);
});

    // Cart
    Route::prefix('cart')->group(function () {
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
        Route::get('{conversation}', [ConversationController::class, 'show']);
        Route::post('{conversation}/messages', [ConversationController::class, 'sendMessage']);
        Route::post('{conversation}/audio', [ConversationController::class, 'sendAudio'])->middleware('feature:chat_audio');
        Route::post('{conversation}/file', [ConversationController::class, 'sendFile'])->middleware('feature:chat_file');
        Route::delete('{conversation}', [ConversationController::class, 'destroy']);
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
        Route::post('{notification}/read', [NotificationController::class, 'markRead']);
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
    Route::prefix('transactions')->group(function () {
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
    });

    // Reviews (V2 — désactivé en V1)
    Route::middleware('feature:reviews')->group(function () {
        Route::post('reviews', [ReviewController::class, 'create']);
        Route::post('reviews/{review}/respond', [ReviewController::class, 'respond']);
    });
});

// ─── Admin ───────────────────────────────────────────────────────────────────
Route::prefix('admin')
    ->middleware(['auth:sanctum', 'role:admin,super_admin'])
    ->group(function () {
        // Dashboard
        Route::get('dashboard/metrics', [AdminController::class, 'metrics']);
        Route::get('dashboard/real-time', [AdminController::class, 'realTime']);

        // Users
        Route::get('users', [AdminUserController::class, 'index']);
        Route::get('users/{user}', [AdminUserController::class, 'show']);
        Route::post('users/{user}/suspend', [AdminUserController::class, 'suspend']);
        Route::post('users/{user}/activate', [AdminUserController::class, 'activate']);
        Route::post('users/{user}/verify-kyc', [AdminUserController::class, 'verifyKyc']);
        Route::post('users/{user}/adjust-trust', [AdminUserController::class, 'adjustTrust']);
        Route::post('users/{user}/send-notification', [AdminUserController::class, 'sendNotification']);
        Route::delete('users/{user}', [AdminUserController::class, 'destroy']);
        Route::post('users/{user}/ban', [AdminUserController::class, 'ban']);

        // Badges (admin)
        Route::post('users/{user}/badges', [BadgeController::class, 'award']);
        Route::delete('users/{user}/badges/{badgeType}', [BadgeController::class, 'revoke']);

        // Categories management
        Route::post('categories', [CategoryController::class, 'store']);
        Route::put('categories/{category}', [CategoryController::class, 'update']);
        Route::delete('categories/{category}', [CategoryController::class, 'destroy']);

        // Moderation
        Route::get('moderation/pending', [ContentModerationController::class, 'pending']);
        Route::post('moderation/bulk-action', [ContentModerationController::class, 'bulkAction']);

        // Signalements produits/utilisateurs — jusqu'ici enregistrés (ou pas,
        // a cause d'un bug) mais jamais consultables par l'admin.
        Route::get('reports/products', [ContentModerationController::class, 'productReports']);
        Route::post('reports/products/{report}/resolve', [ContentModerationController::class, 'resolveProductReport']);
        Route::get('reports/reported-users', [ContentModerationController::class, 'userReports']);
        Route::post('reports/reported-users/{report}/resolve', [ContentModerationController::class, 'resolveUserReport']);
        Route::get('reports/support-tickets', [ContentModerationController::class, 'supportTickets']);
        Route::post('reports/support-tickets/{ticket}/resolve', [ContentModerationController::class, 'resolveSupportTicket']);
        Route::post('videos/{video}/moderate', [ContentModerationController::class, 'moderate']);

        // Security
        Route::get('security/alerts', [SecurityController::class, 'alerts']);
        Route::get('security/logs', [SecurityController::class, 'logs']);
        Route::post('security/ip-ban', [SecurityController::class, 'banIp']);

        // Reports
        Route::get('reports/transactions', [AdminController::class, 'transactionReport']);
        Route::get('reports/fraud', [AdminController::class, 'fraudReport']);
        Route::get('reports/users', [AdminController::class, 'userReport']);
        Route::get('reports/overview', [AdminController::class, 'overviewReport']);

        // System — reset/delete-all-videos déplacés en commandes Artisan
        // (quinch:reset-data / quinch:delete-all-videos), volontairement non
        // exposés en HTTP même sous rôle admin (action destructrice).
    });

// ─── Webhooks ────────────────────────────────────────────────────────────────
Route::prefix('webhooks')->group(function () {
    Route::post('orange-money', [TransactionController::class, 'webhookOrangeMoney']);
    Route::post('wave', [TransactionController::class, 'webhookWave']);
    Route::post('wave-premium', [PremiumController::class, 'webhookWave']);
    Route::post('wave-listing', [ProductController::class, 'webhookWaveListingFee']);
});

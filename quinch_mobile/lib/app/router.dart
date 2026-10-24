import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';
import '../features/account/account_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/explore/explore_page.dart';
import '../features/favorites/favorites_page.dart';
import '../features/feed/feed_page.dart';
import '../features/notifications/notification_detail_page.dart';
import '../features/notifications/notification_preferences_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/premium/premium_page.dart';
import '../features/product/product_detail_page.dart';
import '../features/profile/blocked_users_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/my_products_page.dart';
import '../features/profile/seller_profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/rankings/rankings_page.dart';
import '../features/search/search_page.dart';
import '../features/shell/main_shell.dart';
import '../features/support/support_page.dart';
import '../features/shell/placeholder_pages.dart';

const splashPath = '/splash';
const loginPath = '/login';
const registerPath = '/register';
const forgotPasswordPath = '/forgot-password';
const feedPath = '/feed';
const explorePath = '/explore';
const favoritesPath = '/favorites';
const accountPath = '/account';
const searchPath = '/search';

/// Écran d'accueil après connexion.
const homePath = feedPath;

String productPath(String slug) => '/product/${Uri.encodeComponent(slug)}';

const editProfilePath = '/profile/edit';
const myProductsPath = '/my-products';
const blockedUsersPath = '/blocked-users';
const supportPath = '/support';
const settingsPath = '/settings';
const premiumPath = '/premium';
const rankingsPath = '/rankings';
const notificationsPath = '/notifications';
const notificationPreferencesPath = '/notification-preferences';

String notificationPath(String id) =>
    '/notifications/${Uri.encodeComponent(id)}';

String sellerPath(String username) =>
    '/seller/${Uri.encodeComponent(username)}';

/// Écrans accessibles sans session.
const publicPaths = <String>{loginPath, registerPath, forgotPasswordPath};

/// Règle de redirection pure (testable sans Flutter ni Riverpod).
/// Renvoie null si l'écran demandé est autorisé.
String? resolveRedirect(SessionState session, String location) {
  switch (session) {
    case SessionStarting():
    case SessionUnavailable():
      return location == splashPath ? null : splashPath;
    case SessionUnauthenticated():
      return publicPaths.contains(location) ? null : loginPath;
    case SessionAuthenticated():
      return (location == splashPath || publicPaths.contains(location))
          ? homePath
          : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
    refresh.value++;
  });
  final router = GoRouter(
    initialLocation: splashPath,
    refreshListenable: refresh,
    redirect: (context, state) =>
        resolveRedirect(ref.read(sessionControllerProvider), state.uri.path),
    routes: <RouteBase>[
      GoRoute(
        path: splashPath,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(path: loginPath, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: registerPath,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: forgotPasswordPath,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: feedPath,
                builder: (context, state) => const FeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: explorePath,
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: favoritesPath,
                builder: (context, state) => const FavoritesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: accountPath,
                builder: (context, state) => const AccountPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: searchPath,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: editProfilePath,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: myProductsPath,
        builder: (context, state) => const MyProductsPage(),
      ),
      GoRoute(
        path: blockedUsersPath,
        builder: (context, state) => const BlockedUsersPage(),
      ),
      GoRoute(
        path: supportPath,
        builder: (context, state) => const SupportPage(),
      ),
      GoRoute(
        path: settingsPath,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: premiumPath,
        builder: (context, state) => const PremiumPage(),
      ),
      GoRoute(
        path: rankingsPath,
        builder: (context, state) => const RankingsPage(),
      ),
      GoRoute(
        path: notificationsPath,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: notificationPreferencesPath,
        builder: (context, state) => const NotificationPreferencesPage(),
      ),
      GoRoute(
        path: '/notifications/:id',
        builder: (context, state) =>
            NotificationDetailPage(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/seller/:username',
        builder: (context, state) =>
            SellerProfilePage(username: state.pathParameters['username'] ?? ''),
      ),
      GoRoute(
        path: '/product/:slug',
        builder: (context, state) =>
            ProductDetailPage(slug: state.pathParameters['slug'] ?? ''),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

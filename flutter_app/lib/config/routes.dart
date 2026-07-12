import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/marketplace/marketplace_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/sell/sell_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/transactions/transactions_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/seller_profile_screen.dart';
import '../screens/profile/followers_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/auth/google_login_screen.dart';
import '../screens/auth/google_add_phone_screen.dart';


final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final publicRoutes = ['/feed', '/marketplace'];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation) ||
          state.matchedLocation.startsWith('/product/') ||
          state.matchedLocation.startsWith('/seller/') ||
          state.matchedLocation.startsWith('/followers/');

      if (!isAuthenticated && !isAuthRoute && !isPublicRoute) {
        return '/auth/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/feed';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) => const NoTransitionPage(child: FeedScreen()),
          ),
          GoRoute(
            path: '/marketplace',
            pageBuilder: (context, state) => const NoTransitionPage(child: MarketplaceScreen()),
          ),
          GoRoute(
            path: '/sell',
            pageBuilder: (context, state) => const NoTransitionPage(child: SellScreen()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) => const NoTransitionPage(child: ConversationsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(path: '/google-login', builder: (_, __) => const GoogleLoginScreen()),
          GoRoute(path: '/google-add-phone', builder: (_, __) => const GoogleAddPhoneScreen()),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: '/product/:slug',
        builder: (context, state) => ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/seller/:username',
        builder: (context, state) => SellerProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          return ChatScreen(conversationId: id);
        },
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(
        path: '/followers/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final name = state.uri.queryParameters['name'];
          final tab = state.uri.queryParameters['tab'] ?? 'followers';
          return FollowersScreen(userId: userId, name: name, initialTab: tab);
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      // Le panneau admin est retiré de l'app Flutter : Angular est l'unique
      // interface d'administration (voir frontend/). Cette route existait
      // sans aucune vérification de rôle : n'importe quel utilisateur connecté
      // pouvait y accéder (les appels API échouaient ensuite en 403, mais
      // l'écran ne devrait même pas être atteignable).
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quinch_mobile/app/router.dart';
import 'package:quinch_mobile/core/config/app_config.dart';
import 'package:quinch_mobile/core/media/picked_image.dart';
import 'package:quinch_mobile/core/platform/image_picker.dart';
import 'package:quinch_mobile/core/platform/url_opener.dart';
import 'package:quinch_mobile/core/platform/video_session.dart';
import 'package:quinch_mobile/core/providers.dart';
import 'package:quinch_mobile/core/session/session_controller.dart';
import 'package:quinch_mobile/features/chat/chat_providers.dart';
import 'package:quinch_mobile/features/legal/legal_content.dart';
import 'package:quinch_mobile/features/legal/legal_providers.dart';
import 'package:quinch_mobile/features/notifications/notification_providers.dart';
import 'package:quinch_mobile/features/premium/premium_providers.dart';
import 'package:quinch_mobile/features/product/product_providers.dart';
import 'package:quinch_mobile/features/profile/profile_providers.dart';

import 'fakes.dart';

/// Ce que renvoie `pumpScreen` : le conteneur Riverpod, le routeur et les faux dépôts.
class ScreenEnv {
  ScreenEnv({
    required this.container,
    required this.router,
    required this.products,
    required this.profile,
    required this.safety,
    required this.auth,
    required this.favorites,
    required this.notifications,
    required this.premium,
    required this.rankings,
    required this.legal,
    required this.video,
    required this.chat,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeProductRepository products;
  final FakeProfileRepository profile;
  final FakeSafetyRepository safety;
  final FakeAuthRepository auth;
  final FakeFavoritesRepository favorites;
  final FakeNotificationRepository notifications;
  final FakePremiumRepository premium;
  final FakeRankingRepository rankings;
  final FakeLegalRepository legal;
  final FakeVideoFactory video;
  final FakeChatRepository chat;
}

/// Monte un écran au-dessus d'un écran « RACINE » (le retour fonctionne), dans
/// un routeur minimal où les autres destinations sont des textes repères
/// `ROUTE <chemin>`. Aucun réseau : tous les dépôts sont factices.
Future<ScreenEnv> pumpScreen(
  WidgetTester tester,
  Widget page, {
  FakeProductRepository? products,
  FakeProfileRepository? profile,
  FakeSafetyRepository? safety,
  FakeAuthRepository? auth,
  FakeFavoritesRepository? favorites,
  FakeNotificationRepository? notifications,
  FakePremiumRepository? premium,
  FakeRankingRepository? rankings,
  FakeLegalRepository? legal,
  ImagePick? pickImage,
  ImagesPick? pickImages,
  VideoPick? pickVideo,
  FakeVideoFactory? video,
  FakeChatRepository? chat,
  List<Uri>? openedUrls,
  bool urlOpens = true,
  bool authenticated = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final productsRepo = products ?? FakeProductRepository();
  final profileRepo = profile ?? FakeProfileRepository();
  final safetyRepo = safety ?? FakeSafetyRepository();
  final authRepo = auth ?? FakeAuthRepository();
  final favoritesRepo = favorites ?? FakeFavoritesRepository();
  final notificationsRepo = notifications ?? FakeNotificationRepository();
  final premiumRepo = premium ?? FakePremiumRepository();
  final rankingsRepo = rankings ?? FakeRankingRepository();
  final legalRepo = legal ?? FakeLegalRepository();
  final videoFactory = video ?? FakeVideoFactory();
  final chatRepo = chat ?? FakeChatRepository();
  final opened = openedUrls ?? <Uri>[];

  final storage = InMemoryTokenStorage();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse('https://api.quinch.sn/api/v1', allowInsecure: false),
      ),
      productRepositoryProvider.overrideWithValue(productsRepo),
      favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      safetyRepositoryProvider.overrideWithValue(safetyRepo),
      authRepositoryProvider.overrideWithValue(authRepo),
      notificationRepositoryProvider.overrideWithValue(notificationsRepo),
      premiumRepositoryProvider.overrideWithValue(premiumRepo),
      rankingRepositoryProvider.overrideWithValue(rankingsRepo),
      legalRepositoryProvider.overrideWithValue(legalRepo),
      // Par défaut : galerie fermée sans choix (jamais le vrai plugin en test).
      imagePickProvider.overrideWithValue(pickImage ?? () async => null),
      imagesPickProvider.overrideWithValue(
        pickImages ?? () async => <PickedImage>[],
      ),
      videoPickProvider.overrideWithValue(pickVideo ?? () async => null),
      videoSessionFactoryProvider.overrideWithValue(videoFactory.create),
      chatRepositoryProvider.overrideWithValue(chatRepo),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return urlOpens;
      }),
      tokenStorageProvider.overrideWithValue(storage),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 19)),
    ],
  );
  addTearDown(container.dispose);

  if (authenticated) {
    storage.token = 'tok';
    storage.issuedAt = DateTime.utc(2026, 10, 18);
    await container.read(sessionControllerProvider.notifier).start();
  }

  Widget marker(String text) => Scaffold(body: Center(child: Text(text)));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => marker('RACINE')),
      GoRoute(path: '/page', builder: (context, state) => page),
      GoRoute(
        path: loginPath,
        builder: (context, state) => marker('ROUTE $loginPath'),
      ),
      GoRoute(
        path: editProfilePath,
        builder: (context, state) => marker('ROUTE $editProfilePath'),
      ),
      GoRoute(
        path: myProductsPath,
        builder: (context, state) => marker('ROUTE $myProductsPath'),
      ),
      GoRoute(
        path: messagesPath,
        builder: (context, state) => marker('ROUTE $messagesPath'),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (context, state) =>
            marker('ROUTE /messages/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: editProductPath,
        builder: (context, state) => marker('ROUTE $editProductPath'),
      ),
      GoRoute(
        path: sellPath,
        builder: (context, state) => marker('ROUTE $sellPath'),
      ),
      GoRoute(
        path: blockedUsersPath,
        builder: (context, state) => marker('ROUTE $blockedUsersPath'),
      ),
      GoRoute(
        path: supportPath,
        builder: (context, state) => marker('ROUTE $supportPath'),
      ),
      GoRoute(
        path: settingsPath,
        builder: (context, state) => marker('ROUTE $settingsPath'),
      ),
      GoRoute(
        path: premiumPath,
        builder: (context, state) => marker('ROUTE $premiumPath'),
      ),
      GoRoute(
        path: rankingsPath,
        builder: (context, state) => marker('ROUTE $rankingsPath'),
      ),
      GoRoute(
        path: notificationsPath,
        builder: (context, state) => marker('ROUTE $notificationsPath'),
      ),
      GoRoute(
        path: notificationPreferencesPath,
        builder: (context, state) =>
            marker('ROUTE $notificationPreferencesPath'),
      ),
      for (final doc in LegalDocKey.values)
        GoRoute(
          path: doc.path,
          builder: (context, state) => marker('ROUTE ${doc.path}'),
        ),
      GoRoute(
        path: '/notifications/:id',
        builder: (context, state) =>
            marker('ROUTE /notifications/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/seller/:username',
        builder: (context, state) =>
            marker('ROUTE /seller/${state.pathParameters['username']}'),
      ),
      GoRoute(
        path: '/product/:slug',
        builder: (context, state) =>
            marker('ROUTE /product/${state.pathParameters['slug']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/page');
  await tester.pumpAndSettle();

  return ScreenEnv(
    container: container,
    router: router,
    products: productsRepo,
    profile: profileRepo,
    safety: safetyRepo,
    auth: authRepo,
    favorites: favoritesRepo,
    notifications: notificationsRepo,
    premium: premiumRepo,
    rankings: rankingsRepo,
    legal: legalRepo,
    video: videoFactory,
    chat: chatRepo,
  );
}

Finder fieldByLabel(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

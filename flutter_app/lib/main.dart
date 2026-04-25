import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';

import 'config/api_config.dart';
import 'config/theme.dart';
import 'config/routes.dart';


import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';
import 'services/cart_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/favorite_service.dart';
import 'services/user_service.dart';
import 'services/follow_service.dart';
import 'services/transaction_service.dart';
import 'services/negotiation_service.dart';
import 'services/review_service.dart';
import 'services/admin_service.dart';
import 'services/push_notification_service.dart';


import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set timeago locale to French
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize API config (detects emulator vs real device)
  await ApiConfig.init();

  // Initialize core services
  final apiService = ApiService();
  final authService = AuthService(apiService);

  // Initialize push notifications
  final pushNotifService = PushNotificationService();
  await pushNotifService.initialize(apiService);
  // Request notification permission (Android 13+)
  await pushNotifService.requestPermission();

  // Initialize theme
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Create auth provider first so we can create the router once
  final authProvider = AuthProvider(authService, apiService);

  // Create the router once (avoids GlobalKey duplication)
  final router = createRouter(authProvider);

  // Initialize auth (loads from storage)
  await authProvider.initialize();

  // Start notification polling if authenticated
  if (authProvider.isAuthenticated) {
    pushNotifService.startPolling(interval: const Duration(seconds: 30));
  }
  // Listen for auth changes to start/stop polling
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      pushNotifService.startPolling(interval: const Duration(seconds: 30));
    } else {
      pushNotifService.stopPolling();
    }
  });

  runApp(
    QuinchApp(
      apiService: apiService,
      authService: authService,
      themeProvider: themeProvider,
      authProvider: authProvider,
      router: router,
    ),
  );
}

class QuinchApp extends StatelessWidget {
  final ApiService apiService;
  final AuthService authService;
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  final GoRouter router;

  const QuinchApp({
    super.key,
    required this.apiService,
    required this.authService,
    required this.themeProvider,
    required this.authProvider,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services (singletons)
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<ProductService>(
            create: (_) => ProductService(apiService)),
        Provider<CartService>(create: (_) => CartService(apiService)),
        Provider<ChatService>(create: (_) => ChatService(apiService)),
        Provider<NotificationApiService>(
            create: (_) => NotificationApiService(apiService)),
        Provider<FavoriteService>(
            create: (_) => FavoriteService(apiService)),
        Provider<UserService>(create: (_) => UserService(apiService)),
        Provider<FollowService>(
            create: (_) => FollowService(apiService)),
        Provider<TransactionService>(
            create: (_) => TransactionService(apiService)),
        Provider<NegotiationService>(
            create: (_) => NegotiationService(apiService)),
        Provider<ReviewService>(
            create: (_) => ReviewService(apiService)),
        Provider<AdminService>(
            create: (_) => AdminService(apiService)),

        // State providers
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CartProvider>(
          create: (ctx) => CartProvider(ctx.read<CartService>()),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<ChatService>()),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (ctx) =>
              NotificationProvider(ctx.read<NotificationApiService>()),
        ),
        ChangeNotifierProvider<FavoriteProvider>(
          create: (ctx) => FavoriteProvider(ctx.read<FavoriteService>()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          // Set AppColors.isDark so all theme-aware colors update globally
          if (theme.themeMode == ThemeMode.system) {
            AppColors.isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          } else {
            AppColors.isDark = theme.themeMode == ThemeMode.dark;
          }
          return MaterialApp.router(
            title: 'QUINCH',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            routerConfig: router,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

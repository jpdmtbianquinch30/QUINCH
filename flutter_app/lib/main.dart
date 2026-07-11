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



void main() {
  WidgetsFlutterBinding.ensureInitialized();

  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // runApp() est appelé TOUT DE SUITE : le splash natif Android disparaît
  // dès cette frame. Le beau splash animé prend le relais pendant que
  // l'initialisation (API, auth, push notif) se fait en arrière-plan.
  runApp(QuinchApp(bootstrap: _bootstrap()));
}

class AppServices {
  final ApiService apiService;
  final AuthService authService;
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  final GoRouter router;
  final PushNotificationService pushNotifService;

  AppServices({
    required this.apiService,
    required this.authService,
    required this.themeProvider,
    required this.authProvider,
    required this.router,
    required this.pushNotifService,
  });
}

Future<AppServices> _bootstrap() async {
  await ApiConfig.init();

  final apiService = ApiService();
  final authService = AuthService(apiService);

  final pushNotifService = PushNotificationService();
  await pushNotifService.initialize(apiService);
  await pushNotifService.requestPermission();

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  final authProvider = AuthProvider(authService, apiService);
  final router = createRouter(authProvider);
  await authProvider.initialize();

  if (authProvider.isAuthenticated) {
    pushNotifService.startPolling(interval: const Duration(seconds: 30));
  }
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      pushNotifService.startPolling(interval: const Duration(seconds: 30));
    } else {
      pushNotifService.stopPolling();
    }
  });

  // Garantit que l'animation d'entrée a le temps de se jouer
  // même si le bootstrap est très rapide (évite un flash brutal).
  await Future.delayed(const Duration(milliseconds: 600));

  return AppServices(
    apiService: apiService,
    authService: authService,
    themeProvider: themeProvider,
    authProvider: authProvider,
    router: router,
    pushNotifService: pushNotifService,
  );
}

class QuinchApp extends StatelessWidget {
  final Future<AppServices> bootstrap;
  const QuinchApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: bootstrap,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFF06060C),
              body: SizedBox.expand(),
            ),
          );
        }
        return _QuinchAppReady(services: snapshot.data!);
      },
    );
  }
}

class _QuinchAppReady extends StatelessWidget {
  final AppServices services;
  const _QuinchAppReady({required this.services});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: services.apiService),
        Provider<AuthService>.value(value: services.authService),
        Provider<ProductService>(create: (_) => ProductService(services.apiService)),
        Provider<CartService>(create: (_) => CartService(services.apiService)),
        Provider<ChatService>(create: (_) => ChatService(services.apiService)),
        Provider<NotificationApiService>(create: (_) => NotificationApiService(services.apiService)),
        Provider<FavoriteService>(create: (_) => FavoriteService(services.apiService)),
        Provider<UserService>(create: (_) => UserService(services.apiService)),
        Provider<FollowService>(create: (_) => FollowService(services.apiService)),
        Provider<TransactionService>(create: (_) => TransactionService(services.apiService)),
        Provider<NegotiationService>(create: (_) => NegotiationService(services.apiService)),
        Provider<ReviewService>(create: (_) => ReviewService(services.apiService)),
        Provider<AdminService>(create: (_) => AdminService(services.apiService)),

        ChangeNotifierProvider<ThemeProvider>.value(value: services.themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: services.authProvider),
        ChangeNotifierProvider<CartProvider>(create: (ctx) => CartProvider(ctx.read<CartService>())),
        ChangeNotifierProvider<ChatProvider>(create: (ctx) => ChatProvider(ctx.read<ChatService>())),
        ChangeNotifierProvider<NotificationProvider>(create: (ctx) => NotificationProvider(ctx.read<NotificationApiService>())),
        ChangeNotifierProvider<FavoriteProvider>(create: (ctx) => FavoriteProvider(ctx.read<FavoriteService>())),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
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
            routerConfig: services.router,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

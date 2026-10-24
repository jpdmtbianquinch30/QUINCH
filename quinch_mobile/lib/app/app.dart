import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/features/feature_availability.dart';
import '../core/session/session_controller.dart';
import 'router.dart';
import 'theme.dart';

class QuinchApp extends ConsumerStatefulWidget {
  const QuinchApp({super.key});

  @override
  ConsumerState<QuinchApp> createState() => _QuinchAppState();
}

class _QuinchAppState extends ConsumerState<QuinchApp> {
  @override
  void initState() {
    super.initState();
    // Instancie le service de disponibilité : il sonde les fonctions à la connexion.
    ref.read(featureAvailabilityProvider);
    // Restauration de session après le premier rendu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QUINCH',
      debugShowCheckedModeBanner: false,
      theme: QuinchTheme.light(),
      darkTheme: QuinchTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Affiché si la configuration (API_BASE_URL) est absente ou non conforme.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QUINCH',
      debugShowCheckedModeBanner: false,
      theme: QuinchTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuration invalide.\n$message',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

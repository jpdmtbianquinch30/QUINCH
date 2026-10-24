import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig? config;
  String? configError;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigException catch (e) {
    configError = e.message;
  }

  if (config == null) {
    runApp(
      ConfigErrorApp(message: configError ?? 'Configuration introuvable.'),
    );
    return;
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const QuinchApp(),
    ),
  );
}

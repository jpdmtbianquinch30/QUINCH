import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';

/// Écran de chargement affiché au démarrage (restauration de la session).

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (session) {
              SessionUnavailable(:final error) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.userMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.read(sessionControllerProvider.notifier).start(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
              _ => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QUINCH',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(semanticsLabel: 'Chargement'),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

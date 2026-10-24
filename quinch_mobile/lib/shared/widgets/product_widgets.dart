import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/network/api_error.dart';
import '../../core/providers.dart';

/// Image d'annonce : adresse résolue sur le serveur, indicateur de chargement,
/// repli propre si l'image est absente ou illisible.
class QuinchImage extends ConsumerWidget {
  const QuinchImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(mediaUrlProvider).resolve(url);
    if (resolved == null) {
      return const _ImagePlaceholder();
    }
    return Image.network(
      resolved,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        final total = progress.expectedTotalBytes;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: total == null
                  ? null
                  : progress.cumulativeBytesLoaded / total,
            ),
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: scheme.outline),
      ),
    );
  }
}

/// Étiquette « Produit » / « Service » : le service est vert, comme sur le site.
class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key});

  final String type;

  @override
  Widget build(BuildContext context) {
    final isService = type == 'service';
    final color = isService ? QuinchColors.secondary : QuinchColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isService ? 'Service' : 'Produit',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Durée d'une vidéo au format m:ss.
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  factory ErrorRetry.fromError(
    Object? error, {
    Key? key,
    required VoidCallback onRetry,
  }) {
    final message = error is ApiError
        ? error.userMessage
        : 'Une erreur est survenue.';
    return ErrorRetry(key: key, message: message, onRetry: onRetry);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

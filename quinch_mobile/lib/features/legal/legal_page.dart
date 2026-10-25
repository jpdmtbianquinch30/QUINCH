import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error.dart';
import 'legal_content.dart';
import 'legal_providers.dart';

/// Texte juridique (conditions, confidentialité, mentions légales).
///
/// Accessible sans connexion : l'inscription doit pouvoir les afficher. Le texte
/// est celui du projet web ; seules les informations de l'éditeur viennent du
/// serveur. Si le serveur est injoignable, on n'affiche PAS un texte dont
/// l'éditeur serait vide : on propose de réessayer.
class LegalPage extends ConsumerWidget {
  const LegalPage({super.key, required this.docKey});

  final LegalDocKey docKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(legalInfoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(docKey.label)),
      body: info.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, _) => _LegalError(
          message: error is ApiError
              ? error.userMessage
              : "Impossible d'afficher ce texte pour le moment.",
          onRetry: () => ref.invalidate(legalInfoProvider),
        ),
        data: (data) => _LegalDocumentView(
          document: buildLegalDocument(docKey, data),
          current: docKey,
        ),
      ),
    );
  }
}

class _LegalError extends StatelessWidget {
  const _LegalError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _LegalDocumentView extends StatelessWidget {
  const _LegalDocumentView({required this.document, required this.current});

  final LegalDocument document;
  final LegalDocKey current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Semantics(
            header: true,
            child: Text(document.title, style: theme.textTheme.headlineSmall),
          ),
          if (document.version.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Version ${document.version}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          for (final section in document.sections) ...[
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(section.title, style: theme.textTheme.titleMedium),
            ),
            for (final paragraph in section.paragraphs) ...[
              const SizedBox(height: 8),
              Text(paragraph, style: theme.textTheme.bodyMedium),
            ],
          ],
          const SizedBox(height: 32),
          const Divider(),
          Wrap(
            spacing: 8,
            children: [
              for (final other in LegalDocKey.values)
                if (other != current)
                  TextButton(
                    onPressed: () => context.pushReplacement(other.path),
                    child: Text(other.label),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

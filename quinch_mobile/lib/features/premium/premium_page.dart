import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../core/format/time_ago.dart';
import '../../core/network/api_error.dart';
import '../../core/platform/url_opener.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/premium.dart';
import '../../shared/widgets/product_widgets.dart';
import 'premium_providers.dart';

String planLabel(String? plan) => switch (plan) {
  'monthly' => 'Mensuel',
  'annual' => 'Annuel',
  null => '',
  final other => other,
};

/// Affiche un message. Le messager est capturé AVANT les `await` : il reste
/// utilisable même si l'écran a été reconstruit entre-temps.
void _toast(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class PremiumPage extends ConsumerWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(premiumOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: overview.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(premiumOverviewProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(premiumOverviewProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(status: data.status),
              if (!data.status.isPremium &&
                  data.status.pendingSubscription != null) ...[
                const SizedBox(height: 16),
                const _PendingCard(),
              ],
              if (!data.status.isPremium) ...[
                const SizedBox(height: 24),
                _PlansSection(config: data.config, plans: data.plans),
                if (data.offer != null) ...[
                  const SizedBox(height: 24),
                  _OfferSection(offer: data.offer!),
                ],
              ],
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Classements'),
                subtitle: const Text('Réservés aux comptes Premium'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(rankingsPath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final PremiumStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = status.expiresAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isPremium
                      ? Icons.workspace_premium
                      : Icons.person_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.isPremium
                        ? 'Votre compte est Premium'
                        : 'Votre compte est gratuit',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (status.isPremium) ...[
              const SizedBox(height: 8),
              if (status.plan != null)
                Text('Formule : ${planLabel(status.plan)}'),
              if (expires != null)
                Text(
                  status.daysRemaining == null
                      ? "Valable jusqu'au ${formatDateFr(expires)}"
                      : "Valable jusqu'au ${formatDateFr(expires)} (${status.daysRemaining} jour${status.daysRemaining == 1 ? '' : 's'} restant${status.daysRemaining == 1 ? '' : 's'})",
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un abonnement est en attente de confirmation par le serveur. L'application
/// ne déclare JAMAIS le paiement réussi : elle relit le statut auprès du serveur.
class _PendingCard extends ConsumerStatefulWidget {
  const _PendingCard();

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _checking = false;

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    // Conteneur capturé avant les `await` : `ref` n'est plus utilisable si l'écran
    // est retiré de l'arbre pendant l'attente.
    final container = ProviderScope.containerOf(context);
    setState(() => _checking = true);
    try {
      final overview = await container.refresh(premiumOverviewProvider.future);
      await container.read(sessionControllerProvider.notifier).refreshUser();
      _toast(
        messenger,
        overview.status.isPremium
            ? 'Paiement confirmé : votre compte est Premium.'
            : "Le paiement n'est pas encore confirmé par le serveur.",
      );
    } on ApiError catch (e) {
      _toast(messenger, e.userMessage);
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Un paiement est en attente de confirmation. Une fois payé, cela peut prendre quelques instants.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _checking ? null : _check,
              child: _checking
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Vérification',
                      ),
                    )
                  : const Text('Vérifier mon paiement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.config, required this.plans});

  final PublicConfig config;
  final List<PremiumPlan> plans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Formules', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!config.premiumPayments)
          const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Le paiement n'est pas actif pour la version bêta. Les formules seront disponibles prochainement.",
              ),
            ),
          )
        else if (plans.isEmpty)
          const Text('Aucune formule disponible pour le moment.')
        else
          for (final plan in plans) ...[
            _PlanTile(plan: plan),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PlanTile extends ConsumerStatefulWidget {
  const _PlanTile({required this.plan});

  final PremiumPlan plan;

  @override
  ConsumerState<_PlanTile> createState() => _PlanTileState();
}

class _PlanTileState extends ConsumerState<_PlanTile> {
  bool _busy = false;

  Future<void> _choose() async {
    final plan = widget.plan;
    final messenger = ScaffoldMessenger.of(context);
    // Conteneur capturé avant les `await` : `ref` n'est plus utilisable si l'écran
    // est retiré de l'arbre pendant l'attente.
    final container = ProviderScope.containerOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Formule ${planLabel(plan.id)}'),
        content: Text(
          '${formatPrice(plan.price, plan.currency)}. Vous allez être redirigé vers une page de paiement sécurisée, hors de QUINCH.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final start = await container
          .read(premiumRepositoryProvider)
          .subscribe(plan.id);
      if (start == null) {
        // Aucune adresse https valide fournie : rien n'est ouvert.
        _toast(
          messenger,
          'Le lien de paiement est indisponible. Réessayez plus tard.',
        );
        return;
      }
      final opened = await container.read(urlOpenerProvider)(start.paymentUrl);
      container.invalidate(premiumOverviewProvider);
      _toast(
        messenger,
        opened
            ? 'Paiement en cours de traitement. Revenez ici puis touchez « Vérifier mon paiement ».'
            : "Impossible d'ouvrir la page de paiement.",
      );
    } on ApiError catch (e) {
      _toast(messenger, e.userMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(plan.label.isEmpty ? planLabel(plan.id) : plan.label),
        subtitle: Text(formatPrice(plan.price, plan.currency)),
        trailing: FilledButton(
          onPressed: _busy ? null : _choose,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Envoi en cours',
                  ),
                )
              : const Text('Choisir'),
        ),
      ),
    );
  }
}

class _OfferSection extends ConsumerStatefulWidget {
  const _OfferSection({required this.offer});

  final PremiumOffer offer;

  @override
  ConsumerState<_OfferSection> createState() => _OfferSectionState();
}

class _OfferSectionState extends ConsumerState<_OfferSection> {
  bool _busy = false;

  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    // Conteneur capturé avant les `await` : `ref` n'est plus utilisable si l'écran
    // est retiré de l'arbre pendant l'attente.
    final container = ProviderScope.containerOf(context);
    setState(() => _busy = true);
    try {
      final result = await container
          .read(premiumRepositoryProvider)
          .applyOffer();
      container.invalidate(premiumOverviewProvider);
      _toast(messenger, result.message ?? 'Candidature enregistrée.');
    } on ApiError catch (e) {
      // Ex. 403 « email non vérifié » : on affiche le message du serveur tel quel.
      _toast(messenger, e.userMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offer = widget.offer;
    final status = offer.myStatus;
    final Widget action;
    switch (status) {
      case 'pending':
        action = const Text('Votre candidature est en cours d\'examen.');
      case 'granted':
        action = const Text('Offre accordée. Merci !');
      case 'rejected':
        action = const Text("Votre candidature n'a pas été retenue.");
      default:
        action = offer.slotsLeft <= 0
            ? const Text("Toutes les places de l'offre sont attribuées.")
            : FilledButton(
                onPressed: _busy ? null : _apply,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Envoi en cours',
                        ),
                      )
                    : const Text("Demander l'offre de lancement"),
              );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offre de lancement', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${offer.days} jours de Premium offerts. '
              '${offer.slotsLeft} place${offer.slotsLeft == 1 ? '' : 's'} restante${offer.slotsLeft == 1 ? '' : 's'} sur ${offer.slotsTotal}.',
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../data/models/premium.dart';
import '../../data/repositories/ranking_repository.dart';
import '../../shared/widgets/product_widgets.dart';
import '../premium/premium_providers.dart';

class RankingsPage extends ConsumerWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(rankingPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Classements')),
      body: prefs.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(rankingPreferencesProvider),
        ),
        data: (p) => p.isPremium ? _Body(preferences: p) : const _NotPremium(),
      ),
    );
  }
}

class _NotPremium extends StatelessWidget {
  const _NotPremium();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Les classements sont réservés aux comptes Premium.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(premiumPath),
              child: const Text('Découvrir Premium'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.preferences});

  final RankingPreferences preferences;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late RankingPreferences _prefs = widget.preferences;
  RankingKind _kind = RankingKind.sellers;
  bool _saving = false;

  Future<void> _save({bool? optIn, bool? anonymous}) async {
    if (_saving) {
      return;
    }
    final previous = _prefs;
    final nextOptIn = optIn ?? previous.optIn;
    final nextAnonymous = anonymous ?? previous.anonymous;
    setState(() {
      _prefs = RankingPreferences(
        isPremium: true,
        optIn: nextOptIn,
        anonymous: nextAnonymous,
      );
      _saving = true;
    });
    try {
      final saved = await ref
          .read(rankingRepositoryProvider)
          .updatePreferences(optIn: nextOptIn, anonymous: nextAnonymous);
      if (mounted) {
        setState(() => _prefs = saved);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _prefs = previous);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Apparaître dans les classements'),
          value: _prefs.optIn,
          onChanged: _saving ? null : (v) => _save(optIn: v),
        ),
        SwitchListTile(
          title: const Text('Rester anonyme'),
          subtitle: const Text('Votre nom et votre photo sont masqués.'),
          value: _prefs.anonymous,
          onChanged: (_saving || !_prefs.optIn)
              ? null
              : (v) => _save(anonymous: v),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in RankingKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _kind == RankingKind.products
              ? const _ProductList()
              : _UserList(kind: _kind),
        ),
      ],
    );
  }
}

String _plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

String userMetricText(RankingKind kind, RankingEntry e) => switch (kind) {
  RankingKind.sellers =>
    '${_plural(e.metricInt('score'), 'point', 'points')} · ${_plural(e.metricInt('total_views'), 'vue', 'vues')} · '
        '${_plural(e.metricInt('total_likes'), "j'aime", "j'aime")} · ${_plural(e.metricInt('products_count'), 'annonce', 'annonces')}',
  RankingKind.profiles => _plural(
    e.metricInt('profile_views_count'),
    'visite de profil',
    'visites de profil',
  ),
  RankingKind.followers => _plural(
    e.metricInt('followers_count'),
    'abonné',
    'abonnés',
  ),
  RankingKind.products => '',
};

class _UserList extends ConsumerWidget {
  const _UserList({required this.kind});

  final RankingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(userRankingProvider(kind));
    return ranking.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
      ),
      error: (error, stackTrace) => ErrorRetry.fromError(
        error,
        onRetry: () => ref.invalidate(userRankingProvider(kind)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            message: "Aucun classement pour l'instant.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final e = entries[index];
            final canOpen = !e.anonymous && e.username != null;
            return ListTile(
              leading: _Rank(e.rank),
              title: Text(e.fullName),
              subtitle: Text(userMetricText(kind, e)),
              onTap: canOpen
                  ? () => context.push(sellerPath(e.username!))
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(productRankingProvider);
    return ranking.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
      ),
      error: (error, stackTrace) => ErrorRetry.fromError(
        error,
        onRetry: () => ref.invalidate(productRankingProvider),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            message: "Aucun classement pour l'instant.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final e = entries[index];
            return ListTile(
              leading: _Rank(e.rank),
              title: Text(
                e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_plural(e.viewCount, 'vue', 'vues')}'
                '${e.sellerName == null ? '' : ' · ${e.sellerName}'}',
              ),
              onTap: e.productSlug.isEmpty
                  ? null
                  : () => context.push(productPath(e.productSlug)),
            );
          },
        );
      },
    );
  }
}

class _Rank extends StatelessWidget {
  const _Rank(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        '#$rank',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

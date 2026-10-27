import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/features/feature_availability.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/paging/paged_notifier.dart';
import '../../shared/paging/paged_scroll.dart';
import '../chat/messages_page.dart';
import '../notifications/notifications_page.dart';
import '../product/product_providers.dart';
import 'feed_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  FeedTab _tab = FeedTab.forYou;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  NotifierProvider<FeedController, PagedState<ProductCard>> get _provider =>
      _tab == FeedTab.forYou ? feedForYouProvider : feedFollowingProvider;

  void _ensureLoaded() {
    if (!mounted) {
      return;
    }
    if (ref.read(_provider).status == PagedStatus.idle) {
      ref.read(_provider.notifier).refresh();
    }
  }

  void _selectTab(FeedTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    _ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final followEnabled = ref.watch(featureEnabledProvider(AppFeature.follow));
    // Si les abonnements deviennent indisponibles, on revient à « Pour vous ».
    final tab = followEnabled ? _tab : FeedTab.forYou;
    final provider = tab == FeedTab.forYou
        ? feedForYouProvider
        : feedFollowingProvider;
    final state = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUINCH'),
        actions: const [MessagesButton(), NotificationBell()],
      ),
      body: Column(
        children: [
          if (followEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<FeedTab>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: FeedTab.forYou,
                    label: Text('Pour vous'),
                  ),
                  ButtonSegment(
                    value: FeedTab.following,
                    label: Text('Abonnements'),
                  ),
                ],
                selected: <FeedTab>{tab},
                onSelectionChanged: (selection) => _selectTab(selection.first),
              ),
            ),
          Expanded(
            child: PagedScroll<ProductCard>(
              state: state,
              onRefresh: () => ref.read(provider.notifier).refresh(),
              onLoadMore: () => ref.read(provider.notifier).loadMore(),
              itemBuilder: (context, card) => FeedCard(card: card),
              emptyIcon: Icons.play_circle_outline,
              emptyMessage: tab == FeedTab.following
                  ? "Aucune annonce pour l'instant. Abonnez-vous à des vendeurs pour les retrouver ici."
                  : 'Aucune annonce vidéo pour le moment.',
            ),
          ),
        ],
      ),
    );
  }
}

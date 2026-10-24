import 'package:flutter/material.dart';

import '../widgets/product_widgets.dart';
import 'paged_notifier.dart';

/// Liste ou grille paginée : chargement initial, erreur avec « Réessayer »,
/// état vide, tirer pour actualiser, chargement automatique de la suite.
class PagedScroll<T> extends StatelessWidget {
  const PagedScroll({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyMessage,
    this.crossAxisCount = 1,
    this.childAspectRatio = 1,
    this.padding = const EdgeInsets.all(12),
  });

  final PagedState<T> state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyMessage;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (state.isFirstLoad) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
      );
    }
    if (state.isFirstLoadFailure) {
      return ErrorRetry.fromError(state.error, onRetry: () => onRefresh());
    }
    if (state.isEmptyResult) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 360,
              child: EmptyState(icon: emptyIcon, message: emptyMessage),
            ),
          ],
        ),
      );
    }

    final items = state.items;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (state.status == PagedStatus.loaded &&
              state.hasMore &&
              notification.metrics.extentAfter < 600) {
            onLoadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: crossAxisCount == 1
                  ? SliverList.separated(
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          itemBuilder(context, items[index]),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                    )
                  : SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          itemBuilder(context, items[index]),
                    ),
            ),
            SliverToBoxAdapter(
              child: _Footer(state: state, onLoadMore: onLoadMore),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final PagedState<dynamic> state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.status == PagedStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Chargement de la suite',
          ),
        ),
      );
    }
    if (state.status == PagedStatus.failed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              state.error?.userMessage ?? 'Une erreur est survenue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => onLoadMore(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

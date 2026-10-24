import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../data/models/product.dart';
import '../../shared/widgets/product_widgets.dart';
import '../product/product_providers.dart';

/// Résultats de recherche pour un texte donné (au moins 2 caractères).
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>(
      (ref, query) => ref.watch(productRepositoryProvider).search(query),
    );

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _query = value.trim());
      }
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Rechercher une annonce',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _submit,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _submit('');
              },
            ),
        ],
      ),
      body: _query.length < 2
          ? const EmptyState(
              icon: Icons.search,
              message:
                  'Saisissez au moins 2 caractères pour lancer la recherche.',
            )
          : _Results(query: _query),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider(query));
    return results.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Recherche en cours'),
      ),
      error: (error, stackTrace) => ErrorRetry.fromError(
        error,
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      ),
      data: (data) {
        if (data.products.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            message: 'Aucune annonce trouvée.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: data.products.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _HitTile(hit: data.products[index]),
        );
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final SearchProductHit hit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: QuinchImage(url: hit.coverImage, semanticLabel: hit.title),
        ),
      ),
      title: Text(hit.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        hit.sellerUsername == null
            ? formatFcfa(hit.price)
            : '${formatFcfa(hit.price)} · @${hit.sellerUsername}',
      ),
      trailing: TypeChip(hit.type),
      onTap: () => context.push(productPath(hit.slug)),
    );
  }
}

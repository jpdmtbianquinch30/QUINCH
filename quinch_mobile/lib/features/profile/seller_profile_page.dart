import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/features/feature_availability.dart';
import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../data/models/product.dart';
import '../../data/models/user.dart';
import '../../data/repositories/safety_repository.dart';
import '../../shared/paging/paged_scroll.dart';
import '../../shared/widgets/product_widgets.dart';
import '../../shared/widgets/report_sheet.dart';
import '../chat/contact_seller.dart';
import '../explore/product_tile.dart';
import 'profile_providers.dart';

class SellerProfilePage extends ConsumerStatefulWidget {
  const SellerProfilePage({super.key, required this.username});

  final String username;

  @override
  ConsumerState<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends ConsumerState<SellerProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sellerProductsProvider(widget.username).notifier).refresh();
      }
    });
  }

  String? _myId() {
    final session = ref.read(sessionControllerProvider);
    return session is SessionAuthenticated ? session.user.id : null;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _report(PublicProfile profile) {
    return showReportSheet(
      context,
      title: 'Signaler ce profil',
      reasons: UserReportReason.values.map((r) => r.label).toList(),
      onSubmit: (index, description) => ref
          .read(safetyRepositoryProvider)
          .reportUser(
            profile.id,
            UserReportReason.values[index],
            description: description,
          ),
    );
  }

  Future<void> _block(PublicProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bloquer ${profile.fullName} ?'),
        content: const Text(
          'Cette personne ne pourra plus vous contacter. Vous pourrez la débloquer depuis votre compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      final message = await ref
          .read(safetyRepositoryProvider)
          .blockUser(profile.id);
      if (mounted) {
        _toast(message ?? 'Utilisateur bloqué.');
        context.pop();
      }
    } on ApiError catch (e) {
      if (mounted) {
        _toast(e.userMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(publicProfileProvider(widget.username));
    // Écouté dès l'ouverture : un provider « autoDispose » sans écouteur est libéré.
    final products = ref.watch(sellerProductsProvider(widget.username));
    final notifier = ref.read(sellerProductsProvider(widget.username).notifier);
    final data = profile.valueOrNull;
    final isMe = data != null && data.id == _myId();
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: [
          if (data != null && !isMe)
            PopupMenuButton<String>(
              tooltip: 'Plus d\'actions',
              onSelected: (value) {
                if (value == 'report') {
                  _report(data);
                } else if (value == 'block') {
                  _block(data);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Text('Signaler ce profil'),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text('Bloquer cet utilisateur'),
                ),
              ],
            ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(publicProfileProvider(widget.username)),
        ),
        data: (p) {
          return Column(
            children: [
              _Header(profile: p, isMe: isMe),
              const Divider(height: 1),
              Expanded(
                child: PagedScroll<ProductCard>(
                  state: products,
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  onRefresh: notifier.refresh,
                  onLoadMore: notifier.loadMore,
                  itemBuilder: (context, card) => ProductTile(card: card),
                  emptyIcon: Icons.storefront_outlined,
                  emptyMessage: "Ce vendeur n'a aucune annonce en ligne.",
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.profile, required this.isMe});

  final PublicProfile profile;
  final bool isMe;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  late bool _following = widget.profile.isFollowing;
  late int _followers = widget.profile.followerCount;
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final result = _following
          ? await repo.unfollow(widget.profile.id)
          : await repo.follow(widget.profile.id);
      ref.read(featureAvailabilityProvider.notifier).report(AppFeature.follow);
      if (mounted) {
        setState(() {
          if (result.following != _following) {
            _followers += result.following ? 1 : (_followers > 0 ? -1 : 0);
          }
          _following = result.following;
        });
      }
    } on ApiError catch (e) {
      ref
          .read(featureAvailabilityProvider.notifier)
          .report(AppFeature.follow, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final theme = Theme.of(context);
    final followEnabled = ref.watch(featureEnabledProvider(AppFeature.follow));
    final initial = p.fullName.isEmpty
        ? '?'
        : p.fullName.characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: p.avatarUrl == null
                        ? Center(child: Text(initial))
                        : QuinchImage(
                            url: p.avatarUrl,
                            semanticLabel: p.fullName,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName, style: theme.textTheme.titleLarge),
                    if (p.city != null)
                      Text(p.city!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (p.isPremium) const Chip(label: Text('Premium')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              Text(
                '${p.productsCount} annonce${p.productsCount > 1 ? 's' : ''}',
              ),
              if (followEnabled)
                Text('$_followers abonné${_followers > 1 ? 's' : ''}'),
            ],
          ),
          if (p.bio != null) ...[
            const SizedBox(height: 8),
            Text(p.bio!, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (!widget.isMe) ...[
            const SizedBox(height: 12),
            ContactSellerButton(
              sellerId: p.id,
              label: 'Contacter',
              filled: false,
            ),
          ],
          if (!widget.isMe && followEnabled) ...[
            const SizedBox(height: 12),
            _following
                ? OutlinedButton(
                    onPressed: _busy ? null : _toggleFollow,
                    child: const Text('Abonné'),
                  )
                : FilledButton(
                    onPressed: _busy ? null : _toggleFollow,
                    child: const Text("S'abonner"),
                  ),
          ],
        ],
      ),
    );
  }
}

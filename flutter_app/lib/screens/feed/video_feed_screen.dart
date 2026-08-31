import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/cached_avatar.dart';
import '../search/search_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÉCRAN VIDÉO DÉDIÉ (plein écran, défilement vertical)
/// ───────────────────────────────────────────────────────────────
/// Seul endroit de l'app avec un défilement vertical façon TikTok —
/// volontairement isolé du feed principal, ouvert uniquement quand
/// l'utilisateur tape sur la bannière "Vidéos" ou une carte vidéo.
/// Ne charge/joue que la vidéo courante (+ précharge la suivante),
/// dispose proprement les contrôleurs qui sortent de la fenêtre
/// visible pour éviter les fuites mémoire.
/// ═══════════════════════════════════════════════════════════════

class VideoFeedScreen extends StatefulWidget {
  final List<Product> videos;
  final int initialIndex;

  const VideoFeedScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers = {};
  bool _muted = false;
  bool _speedBoost = false;

  // Animation "cœur" au double-tap (façon Instagram/TikTok)
  Offset? _heartPosition;
  bool _heartVisible = false;
  int? _heartIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initControllerFor(_currentIndex, autoplay: true);
    _preloadNeighbor(_currentIndex);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _initControllerFor(int index, {bool autoplay = false}) {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return;
    final url = widget.videos[index].video?.effectiveUrl ?? '';
    if (url.isEmpty) return;
    final resolved = ApiConfig.resolveUrl(url);
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controllers[index] = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.setVolume(_muted ? 0 : 1);
      if (index == _currentIndex && autoplay) controller.play();
      setState(() {});
    });
  }

  void _preloadNeighbor(int index) {
    _initControllerFor(index + 1);
  }

  void _disposeFarControllers(int keepIndex) {
    final toRemove = <int>[];
    _controllers.forEach((idx, controller) {
      if ((idx - keepIndex).abs() > 1) {
        controller.dispose();
        toRemove.add(idx);
      }
    });
    for (final idx in toRemove) {
      _controllers.remove(idx);
    }
  }

  void _onPageChanged(int index) {
    _controllers[_currentIndex]?.pause();
    setState(() {
      _currentIndex = index;
      _speedBoost = false;
    });
    _initControllerFor(index, autoplay: true);
    _preloadNeighbor(index);
    _disposeFarControllers(index);
    _controllers[index]?.play();
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      for (final c in _controllers.values) {
        c.setVolume(_muted ? 0 : 1);
      }
    });
  }

  // Appui long (gauche ou droite, peu importe) -> lecture x2, comme un
  // "fast forward" temporaire. Relâché -> retour à la vitesse normale.
  void _startSpeedBoost() {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;
    controller.setPlaybackSpeed(2.0);
    setState(() => _speedBoost = true);
  }

  void _stopSpeedBoost() {
    final controller = _controllers[_currentIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.setPlaybackSpeed(1.0);
    }
    if (mounted) setState(() => _speedBoost = false);
  }

  // Double-tap n'importe où sur la vidéo -> like (n'enlève jamais le like
  // existant, comme Instagram : un 2e double-tap ne "unlike" pas).
  Future<void> _handleDoubleTapLike(Product product, int index, Offset position) async {
    if (!product.isLiked) {
      await _toggleLike(product);
    }
    setState(() {
      _heartPosition = position;
      _heartVisible = true;
      _heartIndex = index;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _heartVisible = false);
  }

  Future<void> _toggleSave(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    setState(() => product.isSaved = !product.isSaved);
    try {
      await context.read<ProductService>().toggleSave(product.id);
    } catch (_) {
      if (mounted) setState(() => product.isSaved = !product.isSaved);
    }
  }

  Future<void> _toggleLike(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    final wasLiked = product.isLiked;
    setState(() {
      product.isLiked = !wasLiked;
      product.likeCount += wasLiked ? -1 : 1;
    });
    try {
      await context.read<ProductService>().toggleLike(product.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          product.isLiked = wasLiked;
          product.likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _sendMessageToSeller(Product product, String message) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    if (product.seller == null || product.seller!.id == auth.user?.id) return;
    final chat = context.read<ChatProvider>();
    final convId = await chat.startConversation(
      sellerId: product.seller!.id,
      productId: product.id,
      message: message,
    );
    if (!mounted) return;
    if (convId != null) context.push('/messages/$convId');
  }

  // Même logique 2 étapes que la fiche produit : (1) choix du type de
  // message, (2) aperçu éditable avec un vrai bouton "Envoyer". Rien ne
  // part avant ce tap final — un seul tap, un seul envoi.
  void _showContactOptionsSheet(Product product) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }

    final draftCtrl = TextEditingController();
    bool showingPreview = false;
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),

            if (!showingPreview) ...[
              Text('Contacter ${product.seller?.displayName ?? "le vendeur"}',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              _contactOptionTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Je suis intéressé(e) par ce produit',
                subtitle: 'Propose un message — vous le voyez avant l\'envoi',
                highlighted: true,
                onTap: () {
                  draftCtrl.text = 'Bonjour, je suis intéressé(e) par "${product.title}".';
                  setSt(() => showingPreview = true);
                },
              ),
              const SizedBox(height: 10),
              _contactOptionTile(
                icon: Icons.forum_outlined,
                title: 'Juste discuter',
                subtitle: 'Un message simple, modifiable avant l\'envoi',
                onTap: () {
                  draftCtrl.text = 'Bonjour !';
                  setSt(() => showingPreview = true);
                },
              ),
            ] else ...[
              Row(children: [
                GestureDetector(
                  onTap: () => setSt(() => showingPreview = false),
                  child: Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Aperçu du message', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('Modifiez-le si besoin, rien n\'est envoyé tant que vous n\'appuyez pas sur Envoyer.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(
                controller: draftCtrl,
                maxLines: 4,
                minLines: 2,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  filled: true, fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: sending || draftCtrl.text.trim().isEmpty ? null : () async {
                    setSt(() => sending = true);
                    await _sendMessageToSeller(product, draftCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 18, color: Colors.white),
                  label: Text(sending ? 'Envoi...' : 'Envoyer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _contactOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.accentSubtle : AppColors.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlighted ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: highlighted ? AppColors.accent : AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: highlighted ? Colors.white : AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  // ─── Donner un avis directement depuis le scroll vidéo ───
  // Objectif : inciter à noter le produit/service sans quitter le
  // défilement, plutôt que de le laisser passer sans avis.
  void _showRateSheet(Product product) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    int rating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Text('Donner mon avis', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setSt(() => rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(i < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFBBF24), size: 34),
                ),
              ))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Commentaire (optionnel)...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                filled: true, fillColor: AppColors.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: submitting || rating == 0 || product.seller == null ? null : () async {
                  setSt(() => submitting = true);
                  try {
                    await context.read<ReviewService>().createReview(
                      sellerId: product.seller!.id.toString(),
                      rating: rating,
                      comment: commentCtrl.text.trim().isNotEmpty ? commentCtrl.text.trim() : null,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {
                    setSt(() => submitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publier l\'avis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _buildVideoPage(widget.videos[index], index),
          ),

          // Barre du haut — retour, recherche (identique au feed), son.
          // Manquait jusqu'ici : on ne pouvait pas chercher depuis l'écran
          // vidéo, il fallait revenir en arrière.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      ),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rechercher…',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _circleButton(
                    icon: _muted ? Icons.volume_off : Icons.volume_up,
                    onTap: _toggleMute,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildVideoPage(Product product, int index) {
    final controller = _controllers[index];
    final ready = controller != null && controller.value.isInitialized;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTapDown: (details) =>
          _handleDoubleTapLike(product, index, details.localPosition),
      onLongPressStart: (_) => _startSpeedBoost(),
      onLongPressEnd: (_) => _stopSpeedBoost(),
      onLongPressCancel: _stopSpeedBoost,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Vidéo à son ratio naturel — plus de format 9:16 imposé.
            // Chaque vidéo garde ses propres proportions (portrait,
            // carré, paysage...), centrée avec letterbox si besoin.
            Center(
              child: ready
                  ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
                  : (product.mediaUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.contain)
                  : const ColoredBox(color: Colors.black)),
            ),

            if (!ready)
              const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),

            // Icône pause visible quand en pause
            if (ready && !controller.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, color: Colors.white70, size: 64),
              ),

            // Indicateur de vitesse x2 pendant l'appui long
            if (_speedBoost)
              Positioned(
                top: MediaQuery.of(context).padding.top + 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Vitesse x2',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

            // Cœur du double-tap
            if (_heartVisible && _heartIndex == index && _heartPosition != null)
              Positioned(
                left: _heartPosition!.dx - 45,
                top: _heartPosition!.dy - 45,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 90),
                ),
              ),

            // Scrim bas pour lisibilité
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),

            // Badge produit / service — précise le type directement sur la vidéo
            Positioned(
              top: MediaQuery.of(context).padding.top + 62,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: product.isService ? AppColors.secondary : AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  product.isService ? 'Service' : 'Produit',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Actions à droite (avatar créateur, like, save, contact, avis)
            Positioned(
              right: 12,
              bottom: 130 + bottomSafe,
              child: Column(
                children: [
                  // Avatar rond du créateur — tape pour voir son profil.
                  if (product.seller != null)
                    GestureDetector(
                      onTap: () {
                        final username = product.seller!.username;
                        if (username != null && username.isNotEmpty) {
                          context.push('/seller/$username');
                        }
                      },
                      child: Container(
                        width: 44, height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CachedAvatar(
                          url: product.seller!.avatarUrl,
                          size: 40,
                          name: product.seller!.displayName,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _actionButton(
                    icon: product.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: product.isLiked ? AppColors.liked : Colors.white,
                    label: _fmtCount(product.likeCount),
                    onTap: () => _toggleLike(product),
                  ),
                  const SizedBox(height: 18),
                  // NOTE : pas de compteur de favoris affiché ici — le
                  // modèle Product ne semble pas exposer de champ dédié
                  // (contrairement à likeCount). Si tu as un
                  // `saveCount`/`favoriteCount` côté backend, dis-le-moi
                  // et j'affiche le vrai nombre au lieu du libellé.
                  _actionButton(
                    icon: product.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: product.isSaved ? AppColors.saved : Colors.white,
                    label: 'Sauver',
                    onTap: () => _toggleSave(product),
                  ),
                  const SizedBox(height: 18),
                  _actionButton(
                    icon: Icons.chat_bubble_outline,
                    color: Colors.white,
                    label: 'Contacter',
                    onTap: () => _showContactOptionsSheet(product),
                  ),
                  const SizedBox(height: 18),
                  // NOTE : les avis sont liés au vendeur (pas au produit)
                  // dans ce backend — pas de compteur par-vidéo disponible
                  // pour l'instant, juste l'action de noter.
                  _actionButton(
                    icon: Icons.star_border,
                    color: Colors.white,
                    label: 'Avis',
                    onTap: () => _showRateSheet(product),
                  ),
                ],
              ),
            ),

            // Infos produit en bas à gauche — bouton "Voir le produit"
            // protégé par le padding de zone sûre (il était masqué par la
            // barre de navigation gestuelle du téléphone).
            Positioned(
              left: 16,
              right: 80,
              bottom: 28 + bottomSafe,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.seller != null)
                    GestureDetector(
                      onTap: () {
                        final username = product.seller!.username;
                        if (username != null && username.isNotEmpty) {
                          context.push('/seller/$username');
                        }
                      },
                      child: Text('@${product.seller!.username ?? product.seller!.displayName}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 4),
                  Text(product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(product.displayPrice,
                          style: TextStyle(
                              color: AppColors.accentLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.push('/product/${product.slug}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: const Text('Voir le produit',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
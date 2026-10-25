import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/video_session.dart';
import '../../core/providers.dart';
import '../../data/models/product.dart';

/// Identifiant de la vidéo en cours de lecture : une seule à la fois.
final activeVideoProvider = StateProvider<String?>((ref) => null);

enum _Phase { poster, loading, ready, error }

/// Lecteur vidéo d'une annonce.
///
/// Tant que l'utilisateur n'a pas touché « Lire », seul [poster] est affiché et
/// rien n'est téléchargé (économie de données mobiles). Le son est coupé au
/// départ. La lecture s'arrête quand une autre vidéo démarre, quand l'écran est
/// recouvert ou quitté, et se met en pause quand l'application passe en
/// arrière-plan.
class QuinchVideoPlayer extends ConsumerStatefulWidget {
  const QuinchVideoPlayer({
    super.key,
    required this.video,
    required this.poster,
  });

  final ProductVideo video;

  /// Image affichée avant la lecture (et derrière un message d'erreur).
  final Widget poster;

  @override
  ConsumerState<QuinchVideoPlayer> createState() => _QuinchVideoPlayerState();
}

class _QuinchVideoPlayerState extends ConsumerState<QuinchVideoPlayer>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.poster;
  VideoSession? _session;
  bool _muted = true;

  /// Incrémenté à chaque démarrage ou arrêt : une initialisation lente qui
  /// se termine après un arrêt ne doit rien afficher.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Écran recouvert par un autre (détail, onglet masqué…) : on met en pause.
    if (!TickerMode.of(context)) {
      _pauseQuietly();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pauseQuietly();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _releaseSession();
    super.dispose();
  }

  void _pauseQuietly() {
    final session = _session;
    if (session != null && _phase == _Phase.ready && session.isPlaying) {
      unawaited(session.pause());
    }
  }

  void _releaseSession() {
    final session = _session;
    _session = null;
    if (session != null) {
      session.removeListener(_onTick);
      // Libération différée : on peut être en plein `notifyListeners()` du
      // lecteur (erreur de lecture), et Flutter interdit de le libérer à ce
      // moment-là.
      unawaited(Future<void>.microtask(session.dispose));
    }
  }

  void _onTick() {
    if (!mounted) {
      return;
    }
    final session = _session;
    if (session == null) {
      return;
    }
    if (session.hasError) {
      _fail(_generation);
      return;
    }
    setState(() {});
  }

  void _fail(int generation) {
    if (!mounted || generation != _generation) {
      return;
    }
    _releaseSession();
    setState(() => _phase = _Phase.error);
  }

  Future<void> _start() async {
    final url = ref.read(mediaUrlProvider).resolve(widget.video.streamPath);
    if (url == null) {
      setState(() => _phase = _Phase.error);
      return;
    }
    final generation = ++_generation;
    _releaseSession();
    ref.read(activeVideoProvider.notifier).state = widget.video.id;

    final session = ref.read(videoSessionFactoryProvider)(Uri.parse(url));
    _session = session;
    setState(() => _phase = _Phase.loading);
    try {
      await session.initialize();
      if (!mounted || generation != _generation) {
        return;
      }
      await session.setMuted(muted: _muted);
      session.addListener(_onTick);
      await session.play();
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _phase = _Phase.ready);
    } on Exception {
      _fail(generation);
    }
  }

  void _stop() {
    _generation++;
    _releaseSession();
    if (mounted) {
      setState(() => _phase = _Phase.poster);
    }
  }

  bool _finished(VideoSession session) =>
      session.duration > Duration.zero && session.position >= session.duration;

  Future<void> _togglePlay() async {
    final session = _session;
    if (session == null || _phase != _Phase.ready) {
      return;
    }
    if (session.isPlaying) {
      await session.pause();
    } else if (_finished(session)) {
      await session.restart();
    } else {
      await session.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMute() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final next = !_muted;
    await session.setMuted(muted: next);
    if (mounted) {
      setState(() => _muted = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(activeVideoProvider, (previous, next) {
      if (next != widget.video.id && _phase != _Phase.poster) {
        _stop();
      }
    });
    return switch (_phase) {
      _Phase.poster => _buildPoster(loading: false),
      _Phase.loading => _buildPoster(loading: true),
      _Phase.ready => _buildPlayer(),
      _Phase.error => _buildError(),
    };
  }

  Widget _buildPoster({required bool loading}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.poster,
        Center(
          child: loading
              ? const CircularProgressIndicator(
                  semanticsLabel: 'Chargement de la vidéo',
                )
              : IconButton.filled(
                  tooltip: 'Lire la vidéo',
                  iconSize: 40,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    final session = _session;
    if (session == null) {
      return _buildPoster(loading: false);
    }
    final totalMs = session.duration.inMilliseconds;
    final progress = totalMs > 0
        ? (session.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: session.aspectRatio,
              child: session.buildView(),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('video-surface'),
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Semantics(
                button: true,
                label: session.isPlaying
                    ? 'Mettre la vidéo en pause'
                    : 'Reprendre la vidéo',
                child: Center(
                  child: session.isPlaying
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              tooltip: 'Fermer la vidéo',
              color: Colors.white,
              onPressed: _stop,
              icon: const Icon(Icons.close),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black45,
              child: Row(
                children: [
                  IconButton(
                    tooltip: _muted ? 'Activer le son' : 'Couper le son',
                    color: Colors.white,
                    onPressed: _toggleMute,
                    icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      semanticsLabel: 'Progression de la vidéo',
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.poster,
        const ColoredBox(color: Colors.black54),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vidéo indisponible pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _start, child: const Text('Réessayer')),
            ],
          ),
        ),
      ],
    );
  }
}

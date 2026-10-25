import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Une lecture vidéo. Abstraction minimale au-dessus du plugin `video_player`,
/// pour que les écrans se testent sans décodeur vidéo.
abstract class VideoSession implements Listenable {
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();

  /// Revient au début puis relance la lecture.
  Future<void> restart();
  Future<void> setMuted({required bool muted});

  bool get isInitialized;
  bool get isPlaying;
  bool get hasError;
  Duration get position;
  Duration get duration;
  double get aspectRatio;

  /// Surface d'affichage de l'image (valable après `initialize`).
  Widget buildView();

  /// Libère le décodeur. À appeler une seule fois.
  Future<void> dispose();
}

/// Crée la lecture d'une vidéo à partir de son adresse complète (flux public
/// du serveur, qui accepte les requêtes Range). Aucun jeton n'est envoyé.
typedef VideoSessionFactory = VideoSession Function(Uri url);

class PlatformVideoSession implements VideoSession {
  PlatformVideoSession(Uri url)
    : _controller = VideoPlayerController.networkUrl(url);

  final VideoPlayerController _controller;

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> restart() async {
    await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  @override
  Future<void> setMuted({required bool muted}) =>
      _controller.setVolume(muted ? 0 : 1);

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  bool get hasError => _controller.value.hasError;

  @override
  Duration get position => _controller.value.position;

  @override
  Duration get duration => _controller.value.duration;

  @override
  double get aspectRatio {
    final ratio = _controller.value.aspectRatio;
    return ratio > 0 ? ratio : 16 / 9;
  }

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();
}

final videoSessionFactoryProvider = Provider<VideoSessionFactory>(
  (ref) => PlatformVideoSession.new,
);

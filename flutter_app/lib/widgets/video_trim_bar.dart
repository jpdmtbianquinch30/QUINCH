import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// BARRE D'AJUSTEMENT VIDÉO (TRIM)
/// ───────────────────────────────────────────────────────────────
/// Composant autonome et réutilisable : l'utilisateur choisit la
/// portion de la vidéo à garder via deux curseurs (début / fin),
/// avec aperçu en lecture bouclée sur le segment sélectionné.
///
/// `maxSegmentDuration` est un PARAMÈTRE, pas une valeur figée à
/// 30s — passe la durée que tu veux (ou laisse le défaut). La
/// fenêtre sélectionnée ne peut jamais dépasser cette durée, mais
/// peut être plus courte et déplacée librement sur la timeline.
///
/// ⚠️ CE WIDGET GÈRE UNIQUEMENT LA SÉLECTION DU SEGMENT (UI +
/// PRÉVISUALISATION). L'EXTRACTION RÉELLE (couper le fichier vidéo
/// aux temps choisis) n'est PAS faite ici — deux options existent,
/// et je n'ai pas assez de contexte sur ton écran d'upload pour
/// choisir à ta place :
///
///   A) Côté client avant upload (ex: package `ffmpeg_kit_flutter`)
///      -> plus lourd (taille de l'app, temps de traitement), mais
///         le fichier envoyé au serveur est déjà coupé.
///   B) Côté serveur après upload (le backend reçoit start_ms/end_ms
///      en plus du fichier complet et fait le clip avec ffmpeg côté
///      Laravel) -> upload un peu plus lourd, mais rien à ajouter
///      côté Flutter.
///
/// Dis-moi laquelle tu préfères (ou montre-moi ton écran d'upload
/// vidéo actuel) et je branche `onRangeSelected` dessus.
/// ═══════════════════════════════════════════════════════════════

class VideoTrimBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Duration maxSegmentDuration;

  /// Appelé à chaque changement de sélection, avec le début et la fin
  /// (en millisecondes) du segment actuellement choisi.
  final void Function(Duration start, Duration end) onRangeSelected;

  const VideoTrimBar({
    super.key,
    required this.controller,
    required this.onRangeSelected,
    this.maxSegmentDuration = const Duration(seconds: 30),
  });

  @override
  State<VideoTrimBar> createState() => _VideoTrimBarState();
}

class _VideoTrimBarState extends State<VideoTrimBar> {
  late double _totalSeconds;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.controller.value.duration.inMilliseconds / 1000;
    final maxSeg = widget.maxSegmentDuration.inMilliseconds / 1000;
    final end = _totalSeconds < maxSeg ? _totalSeconds : maxSeg;
    _range = RangeValues(0, end);
    _applyRange();
    widget.controller.addListener(_loopWithinRange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_loopWithinRange);
    super.dispose();
  }

  void _loopWithinRange() {
    final pos = widget.controller.value.position.inMilliseconds / 1000;
    if (pos >= _range.end || pos < _range.start) {
      widget.controller.seekTo(Duration(milliseconds: (_range.start * 1000).round()));
    }
  }

  void _applyRange() {
    widget.onRangeSelected(
      Duration(milliseconds: (_range.start * 1000).round()),
      Duration(milliseconds: (_range.end * 1000).round()),
    );
    widget.controller.seekTo(Duration(milliseconds: (_range.start * 1000).round()));
  }

  String _fmt(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxSeg = widget.maxSegmentDuration.inMilliseconds / 1000;
    final selectedDuration = _range.end - _range.start;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aperçu vidéo
        AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: VideoPlayer(widget.controller),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Segment sélectionné',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${selectedDuration.toStringAsFixed(1)}s / max ${maxSeg.toStringAsFixed(0)}s',
                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.bgElevated,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accentGlow,
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
            trackHeight: 4,
          ),
          child: RangeSlider(
            values: _range,
            min: 0,
            max: _totalSeconds,
            onChanged: (values) {
              // Empêche de sélectionner un segment plus long que le max autorisé :
              // si l'utilisateur élargit trop, on verrouille sur maxSeg en
              // ajustant le curseur qui vient de bouger.
              var start = values.start;
              var end = values.end;
              if (end - start > maxSeg) {
                if (start != _range.start) {
                  start = end - maxSeg;
                } else {
                  end = start + maxSeg;
                }
              }
              setState(() => _range = RangeValues(start, end));
              _applyRange();
            },
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_range.start),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            Text(_fmt(_range.end),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
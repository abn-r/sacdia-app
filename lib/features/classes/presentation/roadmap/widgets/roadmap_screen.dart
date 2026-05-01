import 'package:flutter/material.dart';
import '../data/roadmap_data.dart';
import '../theme/roadmap_tokens.dart';
import 'va_node.dart';
import 'va_path_connector.dart';
import 'va_track_header.dart';
import 'theme_sprites.dart';

/// Pantalla principal del Roadmap de Clases (presentacional pura).
///
/// No incluye Scaffold propio — se integra como child de un contenedor externo
/// (ClassesTabsView) que ya provee el Scaffold del tab de bottom nav.
/// El gradiente de fondo es parte integral del diseño visual y se mantiene
/// usando un Container con BoxDecoration.
///
/// Para usar con datos reales, ver [RoadmapScreenConnected] que envuelve este
/// widget con los estados loading / error / data de [roadmapTracksProvider].
class RoadmapScreen extends StatelessWidget {
  final List<TrackData> tracks;
  final void Function(ClassItem)? onClassTap;

  const RoadmapScreen({
    super.key,
    required this.tracks,
    this.onClassTap,
  });

  @override
  Widget build(BuildContext context) {
    // Stack con gradiente de fondo (mañana → tarde → noche).
    // Se usa Container en lugar de Scaffold para evitar doble Scaffold
    // cuando RoadmapScreen vive dentro de ClassesTabsView.
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.33, 0.66, 1.0],
                colors: [
                  RoadmapTokens.bgAvTop,
                  RoadmapTokens.bgAvBottom,
                  RoadmapTokens.bgCqBottom,
                  RoadmapTokens.bgGmBottom,
                ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            _LegendPills(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final track in tracks)
                      _TrackSection(
                        track: track,
                        onClassTap: onClassTap,
                      ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: const [
          Expanded(
              child: _Pill(
                  label: 'Completada', color: RoadmapTokens.statusDone)),
          Expanded(
              child: _Pill(
                  label: 'Actual', color: RoadmapTokens.statusCurrent)),
          Expanded(
              child: _Pill(
                  label: 'Bloqueada', color: RoadmapTokens.statusLocked)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RoadmapTokens.textPrimary)),
        ],
      ),
    );
  }
}

class _TrackSection extends StatelessWidget {
  final TrackData track;
  final void Function(ClassItem)? onClassTap;

  const _TrackSection({required this.track, this.onClassTap});

  @override
  Widget build(BuildContext context) {
    final accent = RoadmapTokens.hex(track.accent);
    final soft = RoadmapTokens.hex(track.soft);
    final done =
        track.classes.where((c) => c.status == ClassStatus.done).length;

    return Stack(
      children: [
        // Sprites temáticos al fondo de la sección
        Positioned.fill(
          child: ThemeSpritesBackground(
            kind: track.kind,
            height: track.classes.length * 200.0 + 80,
          ),
        ),
        Column(
          children: [
            VATrackHeader(
              title: track.track,
              subtitle: track.ageRange,
              accent: accent,
              soft: soft,
              done: done,
              total: track.classes.length,
            ),
            for (int i = 0; i < track.classes.length; i++)
              _NodeWithConnector(
                index: i,
                cls: track.classes[i],
                accent: accent,
                onTap: onClassTap == null
                    ? null
                    : () => onClassTap!(track.classes[i]),
              ),
          ],
        ),
      ],
    );
  }
}

class _NodeWithConnector extends StatelessWidget {
  final int index;
  final ClassItem cls;
  final Color accent;
  final VoidCallback? onTap;

  const _NodeWithConnector({
    required this.index,
    required this.cls,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final side = index.isEven ? 'left' : 'right';
    final prevSide = index.isEven ? 'right' : 'left';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (index > 0)
          VAPathConnector(side: side, prevSide: prevSide, accentColor: accent),
        VANode(
          item: cls,
          side: side,
          accentColor: accent,
          onTap: onTap,
        ),
      ],
    );
  }
}

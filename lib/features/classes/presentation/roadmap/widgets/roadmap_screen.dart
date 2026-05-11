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
class RoadmapScreen extends StatefulWidget {
  final List<TrackData> tracks;
  final void Function(ClassItem)? onClassTap;

  const RoadmapScreen({
    super.key,
    required this.tracks,
    this.onClassTap,
  });

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _scrollController = ScrollController();

  // GlobalKey que se asigna al nodo con ClassStatus.current.
  // Se usa para Scrollable.ensureVisible en el primer frame.
  final _currentNodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Double-postFrame: el primer callback garantiza que el árbol esté
    // montado; el segundo garantiza que el layout de todos los hijos
    // (incluido el nodo actual, que puede estar debajo del fold) se
    // haya completado antes de llamar a ensureVisible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToCurrentNode());
    });
  }

  void _scrollToCurrentNode() {
    if (!mounted) return;

    final ctx = _currentNodeKey.currentContext;
    if (ctx == null) {
      return; // No hay clase actual o el widget no está en el árbol.
    }

    // Verificar que el RenderObject esté realmente laid out antes de llamar
    // ensureVisible. Si todavía está en NEEDS-LAYOUT la llamada lanzaría
    // una assertion en debug y un no-op silencioso en release.
    final ro = ctx.findRenderObject();
    if (ro == null || !ro.attached) return;
    if (ro is RenderBox && !ro.hasSize) return;

    try {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.3, // 30 % desde el tope visible — deja espacio arriba.
      );
    } catch (e, st) {
      // No crashear si el Scrollable todavía no está listo (e.g., hot-reload
      // parcial o reparenteo durante animación de entrada).
      debugPrint('[RoadmapScreen] ensureVisible failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determinar el id canónico de la clase actual: el PRIMERO que tenga
    // ClassStatus.current recorriendo todos los tracks en orden.
    // Esto garantiza que _currentNodeKey se asigne a UN SOLO VANode aunque
    // el backend devuelva múltiples clases con status == current (e.g. el
    // usuario inscripto en "Guía" y "Guía Mayor" a la vez).
    final String? currentClassId = () {
      for (final t in widget.tracks) {
        for (final c in t.classes) {
          if (c.status == ClassStatus.current) return c.id;
        }
      }
      return null;
    }();

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
                controller: _scrollController,
                child: Column(
                  children: [
                    for (final track in widget.tracks)
                      _TrackSection(
                        track: track,
                        onClassTap: widget.onClassTap,
                        currentClassId: currentClassId,
                        currentNodeKey: _currentNodeKey,
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
              child:
                  _Pill(label: 'Completada', color: RoadmapTokens.statusDone)),
          Expanded(
              child:
                  _Pill(label: 'Actual', color: RoadmapTokens.statusCurrent)),
          Expanded(
              child:
                  _Pill(label: 'Bloqueada', color: RoadmapTokens.statusLocked)),
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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

  /// Id canónico de la clase actual (puede ser null si no hay ninguna).
  /// Solo el nodo cuyo [ClassItem.id] coincida recibirá [currentNodeKey].
  /// Esto garantiza que la key se asigne a COMO MÁXIMO UN widget en el árbol,
  /// incluso cuando el backend devuelva múltiples clases con status == current.
  final String? currentClassId;

  /// Key para el auto-scroll. Nullable porque si [currentClassId] es null
  /// no hay nodo destino y la key no se usa.
  final GlobalKey? currentNodeKey;

  const _TrackSection({
    required this.track,
    required this.currentClassId,
    required this.currentNodeKey,
    this.onClassTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = RoadmapTokens.hex(track.accent);
    final soft = RoadmapTokens.hex(track.soft);
    final done =
        track.classes.where((c) => c.status == ClassStatus.done).length;
    // hasCurrent es true solo si este track contiene la clase canónica actual.
    // Evita mostrar la pill "Cursando" en tracks secundarios con status current.
    final hasCurrent = currentClassId != null &&
        track.classes.any((c) => c.id == currentClassId);

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
              hasCurrent: hasCurrent,
            ),
            for (int i = 0; i < track.classes.length; i++)
              _NodeWithConnector(
                index: i,
                cls: track.classes[i],
                accent: accent,
                currentNodeKey: track.classes[i].id == currentClassId
                    ? currentNodeKey
                    : null,
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

  /// Si no es null, se asigna como [key] al [VANode] para auto-scroll.
  final GlobalKey? currentNodeKey;

  const _NodeWithConnector({
    required this.index,
    required this.cls,
    required this.accent,
    this.currentNodeKey,
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
          key: currentNodeKey,
          item: cls,
          side: side,
          accentColor: accent,
          onTap: onTap,
        ),
      ],
    );
  }
}

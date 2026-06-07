import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/animations/celebration_overlay.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// Pantalla temporal para evaluar el motion language de SACDIA.
///
/// TODO(remove-before-release): quitar esta vista y su acceso en dashboard
/// antes de cerrar la rama de development.
class AnimationDemoView extends StatefulWidget {
  const AnimationDemoView({super.key});

  @override
  State<AnimationDemoView> createState() => _AnimationDemoViewState();
}

class _AnimationDemoViewState extends State<AnimationDemoView>
    with TickerProviderStateMixin {
  late final AnimationController _breathingController;
  late final AnimationController _orbitController;
  late final AnimationController _shimmerController;

  bool _expanded = false;
  bool _selected = false;
  bool _replayToggle = false;
  int _points = 72;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _orbitController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _replay() {
    setState(() {
      _replayToggle = !_replayToggle;
      _points = _points == 72 ? 96 : 72;
      _expanded = false;
      _selected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final hPad = Responsive.horizontalPadding(context);

    final cards = [
      _MotionDemoCard(
        title: 'Entrada escalonada',
        subtitle: 'Ideal para cargar dashboard sin que aparezca todo de golpe.',
        icon: HugeIcons.strokeRoundedDashboardSquare01,
        accent: AppColors.primary,
        child: _StaggerPreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Tap feedback / presión',
        subtitle: 'Microinteracción táctil: responde al dedo, no al mouse.',
        icon: HugeIcons.strokeRoundedTarget01,
        accent: AppColors.secondary,
        child: _PressFeedbackPreview(
          selected: _selected,
          onPressed: () => setState(() => _selected = !_selected),
        ),
      ),
      _MotionDemoCard(
        title: 'Contador + progreso',
        subtitle: 'Bueno para puntos, logros, rankings y clases progresivas.',
        icon: HugeIcons.strokeRoundedAward01,
        accent: AppColors.accent,
        child: _ProgressPreview(points: _points),
      ),
      _MotionDemoCard(
        title: 'Reveal expansivo',
        subtitle: 'Muestra detalle bajo demanda sin navegar innecesariamente.',
        icon: HugeIcons.strokeRoundedAnalytics01,
        accent: AppColors.info,
        child: _ExpandablePreview(
          expanded: _expanded,
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ),
      _MotionDemoCard(
        title: 'Respiración suave',
        subtitle: 'Útil para estados vivos; usar poco para no cansar.',
        icon: HugeIcons.strokeRoundedFlash,
        accent: AppColors.primary,
        child: _BreathingPreview(
          controller: _breathingController,
          enabled: shouldAnimate,
        ),
      ),
      _MotionDemoCard(
        title: 'Órbita / foco guiado',
        subtitle: 'Puede guiar atención en onboarding o tareas importantes.',
        icon: HugeIcons.strokeRoundedCompass01,
        accent: AppColors.secondary,
        child: _OrbitPreview(
          controller: _orbitController,
          enabled: shouldAnimate,
        ),
      ),
      _MotionDemoCard(
        title: 'Skeleton shimmer',
        subtitle:
            'Carga percibida: mejor que un spinner para cards de contenido.',
        icon: HugeIcons.strokeRoundedRefresh,
        accent: AppColors.info,
        child: _ShimmerPreview(controller: _shimmerController),
      ),
      _MotionDemoCard(
        title: 'Celebración puntual',
        subtitle: 'Para hitos reales: clase completada, honor aprobado, racha.',
        icon: HugeIcons.strokeRoundedPlayCircle,
        accent: AppColors.accent,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SacButton.primary(
            text: 'Probar confetti',
            icon: HugeIcons.strokeRoundedAward01,
            onPressed: () => CelebrationOverlay.show(context),
          ),
        ),
      ),
      _MotionDemoCard(
        title: 'Morphing de tarjeta',
        subtitle: 'Cambio de forma/estado sin perder continuidad visual.',
        icon: HugeIcons.strokeRoundedDashboardSquare01,
        accent: AppColors.primary,
        child: const _MorphingCardPreview(),
      ),
      _MotionDemoCard(
        title: 'Flip 3D controlado',
        subtitle: 'Útil para credenciales, reverso de tarjeta o QR.',
        icon: HugeIcons.strokeRoundedCreditCard,
        accent: AppColors.info,
        child: const _FlipCardPreview(),
      ),
      _MotionDemoCard(
        title: 'Swipe reveal',
        subtitle: 'Gesture opcional con acción visible; nunca gesture-only.',
        icon: HugeIcons.strokeRoundedArrowRight01,
        accent: AppColors.secondary,
        child: const _SwipeRevealPreview(),
      ),
      _MotionDemoCard(
        title: 'Stepper / timeline',
        subtitle: 'Para procesos: inscripción, evidencias, investidura.',
        icon: HugeIcons.strokeRoundedAnalytics01,
        accent: AppColors.accent,
        child: _TimelinePreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Liquid progress',
        subtitle:
            'Más expresivo que una barra, ideal para progreso protagonista.',
        icon: HugeIcons.strokeRoundedAward01,
        accent: AppColors.secondary,
        child: _WaveProgressPreview(
          controller: _orbitController,
          progress: _points / 100,
        ),
      ),
      _MotionDemoCard(
        title: 'Status pulse',
        subtitle: 'Estado que necesita atención sin gritar todo el tiempo.',
        icon: HugeIcons.strokeRoundedAlert02,
        accent: AppColors.error,
        child: _StatusPulsePreview(controller: _breathingController),
      ),
      _MotionDemoCard(
        title: 'Texto progresivo',
        subtitle: 'Bueno para onboarding, ayudas y estados guiados.',
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: AppColors.info,
        child: _TypingPreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Parallax de profundidad',
        subtitle:
            'Capas sutiles para headers o cards premium; usar con cuidado.',
        icon: HugeIcons.strokeRoundedCompass01,
        accent: AppColors.primary,
        child: _ParallaxPreview(controller: _orbitController),
      ),
      _MotionDemoCard(
        title: 'Snackbar / toast',
        subtitle: 'Feedback breve para acciones completadas o reversibles.',
        icon: HugeIcons.strokeRoundedAward01,
        accent: AppColors.secondary,
        child: const _SnackbarPreview(),
      ),
      _MotionDemoCard(
        title: 'Menú radial',
        subtitle:
            'Acciones rápidas compactas; útil si no tapa decisiones críticas.',
        icon: HugeIcons.strokeRoundedFiles01,
        accent: AppColors.info,
        child: const _RadialMenuPreview(),
      ),
      _MotionDemoCard(
        title: 'Badge unlock',
        subtitle: 'Delight para logros; NO para cada tap trivial.',
        icon: HugeIcons.strokeRoundedAward01,
        accent: AppColors.accent,
        child: _BadgeUnlockPreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Card stack',
        subtitle: 'Comparación visual de módulos o próximos eventos.',
        icon: HugeIcons.strokeRoundedFolder01,
        accent: AppColors.primary,
        child: _CardStackPreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Dynamic Island',
        subtitle: 'Pill vivo que se expande para estados temporales.',
        icon: HugeIcons.strokeRoundedAlert02,
        accent: AppColors.info,
        child: const _DynamicIslandPreview(),
      ),
      _MotionDemoCard(
        title: 'Mesh gradient vivo',
        subtitle: 'Fondo orgánico moderno, sutil y sin ruido visual.',
        icon: HugeIcons.strokeRoundedAnalytics01,
        accent: AppColors.secondary,
        child: _MeshGradientPreview(controller: _orbitController),
      ),
      _MotionDemoCard(
        title: 'Spotlight border',
        subtitle: 'La tarjeta responde al punto exacto de interacción.',
        icon: HugeIcons.strokeRoundedTarget01,
        accent: AppColors.primary,
        child: const _SpotlightBorderPreview(),
      ),
      _MotionDemoCard(
        title: 'Holographic foil',
        subtitle:
            'Reflejo premium para credenciales, insignias o logros raros.',
        icon: HugeIcons.strokeRoundedCreditCard,
        accent: AppColors.accent,
        child: _HolographicFoilPreview(controller: _orbitController),
      ),
      _MotionDemoCard(
        title: 'Coverflow carousel',
        subtitle: 'Carrusel 3D para recursos destacados o tarjetas visuales.',
        icon: HugeIcons.strokeRoundedFiles01,
        accent: AppColors.info,
        child: const _CoverflowPreview(),
      ),
      _MotionDemoCard(
        title: 'Text scramble',
        subtitle: 'Revelado técnico para códigos, folios o estados especiales.',
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: AppColors.secondary,
        child: _TextScramblePreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Vector line drawing',
        subtitle: 'Dibuja rutas, progreso o caminos de aprendizaje.',
        icon: HugeIcons.strokeRoundedCompass01,
        accent: AppColors.primary,
        child: _LineDrawingPreview(replayKey: _replayToggle),
      ),
      _MotionDemoCard(
        title: 'Liquid wipe',
        subtitle: 'Transición viscosa para cambios de estado con personalidad.',
        icon: HugeIcons.strokeRoundedPlayCircle,
        accent: AppColors.info,
        child: const _LiquidWipePreview(),
      ),
      _MotionDemoCard(
        title: 'Dock magnification',
        subtitle: 'Selector compacto con foco físico tipo dock.',
        icon: HugeIcons.strokeRoundedDashboardSquare01,
        accent: AppColors.primary,
        child: const _DockMagnificationPreview(),
      ),
      _MotionDemoCard(
        title: 'Intelligent auto-sort',
        subtitle: 'Lista viva que reordena prioridades con continuidad.',
        icon: HugeIcons.strokeRoundedAnalytics01,
        accent: AppColors.secondary,
        child: _IntelligentListPreview(controller: _orbitController),
      ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        title: const Text('Demo de animaciones'),
        actions: [
          Semantics(
            label: 'Reiniciar animaciones',
            button: true,
            child: IconButton(
              tooltip: 'Reiniciar',
              onPressed: _replay,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 28),
          itemCount: cards.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _DemoHero(onReplay: _replay);
            }

            return StaggeredListItem(
              key: ValueKey('motion-card-${index - 1}-$_replayToggle'),
              index: index,
              initialDelay: const Duration(milliseconds: 90),
              staggerDelay: const Duration(milliseconds: 55),
              animate: shouldAnimate,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: cards[index - 1],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DemoHero extends StatelessWidget {
  final VoidCallback onReplay;

  const _DemoHero({required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.secondary.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedFlash,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Laboratorio temporal de motion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No es una pantalla final: es un boceto para comparar ritmos, intención y accesibilidad antes de elegir qué animaciones quedan en SACDIA.',
            style: TextStyle(
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SacButton(
            text: 'Reiniciar demo',
            variant: SacButtonVariant.secondary,
            fullWidth: false,
            icon: HugeIcons.strokeRoundedRefresh,
            onPressed: onReplay,
          ),
        ],
      ),
    );
  }
}

class _MotionDemoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final Color accent;
  final Widget child;

  const _MotionDemoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: HugeIcon(icon: icon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: c.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StaggerPreview extends StatelessWidget {
  final bool replayKey;

  const _StaggerPreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    const labels = ['Registro', 'Clase', 'Honor', 'Logro'];
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          StaggeredListItem(
            key: ValueKey('stagger-chip-$i-$replayKey'),
            index: i,
            staggerDelay: const Duration(milliseconds: 90),
            animate: shouldAnimate,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors[i].withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors[i].withValues(alpha: 0.24)),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PressFeedbackPreview extends StatefulWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _PressFeedbackPreview({
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_PressFeedbackPreview> createState() => _PressFeedbackPreviewState();
}

class _PressFeedbackPreviewState extends State<_PressFeedbackPreview> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Alternar tarjeta con feedback táctil',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration:
              shouldAnimate ? const Duration(milliseconds: 120) : Duration.zero,
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.96 : 1,
          child: AnimatedContainer(
            duration: shouldAnimate
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.secondary.withValues(alpha: 0.16)
                  : c.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.selected ? AppColors.secondary : c.border,
                width: widget.selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: widget.selected
                      ? HugeIcons.strokeRoundedAward01
                      : HugeIcons.strokeRoundedTarget01,
                  color:
                      widget.selected ? AppColors.secondary : c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selected ? 'Seleccionada' : 'Tocá para seleccionar',
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPreview extends StatelessWidget {
  final int points;

  const _ProgressPreview({required this.points});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final progress = points / 100;

    return Row(
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: shouldAnimate
                ? const Duration(milliseconds: 750)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    color: AppColors.accent,
                    trackColor: c.border,
                  ),
                  child: Center(
                    child: AnimatedCounter(
                      value: points,
                      suffix: '%',
                      duration: const Duration(milliseconds: 750),
                      animate: shouldAnimate,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progreso de muestra',
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: shouldAnimate
                      ? const Duration(milliseconds: 750)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      minHeight: 10,
                      value: value,
                      color: AppColors.accent,
                      backgroundColor: c.border,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandablePreview extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  const _ExpandablePreview({required this.expanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SacButton(
            text: expanded ? 'Ocultar detalle' : 'Ver detalle',
            variant: SacButtonVariant.secondary,
            fullWidth: true,
            icon: expanded
                ? HugeIcons.strokeRoundedArrowUp01
                : HugeIcons.strokeRoundedArrowDown01,
            onPressed: onPressed,
          ),
        ),
        AnimatedSize(
          duration:
              shouldAnimate ? const Duration(milliseconds: 280) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    'Acá el movimiento ayuda a preservar contexto: el usuario entiende que el detalle pertenece a esta misma tarjeta.',
                    style: TextStyle(color: c.textSecondary, height: 1.4),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _BreathingPreview extends StatelessWidget {
  final AnimationController controller;
  final bool enabled;

  const _BreathingPreview({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (!enabled) {
      return _BreathingBubble(scale: 1, glow: 0.12, textColor: c.text);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = Curves.easeInOut.transform(controller.value);
        return _BreathingBubble(
          scale: 0.96 + (value * 0.08),
          glow: 0.10 + (value * 0.12),
          textColor: c.text,
        );
      },
    );
  }
}

class _BreathingBubble extends StatelessWidget {
  final double scale;
  final double glow;
  final Color textColor;

  const _BreathingBubble({
    required this.scale,
    required this.glow,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: glow),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          'Estado vivo, no invasivo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _OrbitPreview extends StatelessWidget {
  final AnimationController controller;
  final bool enabled;

  const _OrbitPreview({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SizedBox(
      height: 118,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final angle = enabled ? controller.value * math.pi * 2 : 0.0;
          final offset = Offset(math.cos(angle) * 34, math.sin(angle) * 22);

          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 128,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.border),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCompass01,
                    color: c.text,
                  ),
                ),
                Transform.translate(
                  offset: offset,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerPreview extends StatelessWidget {
  final AnimationController controller;

  const _ShimmerPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final alignment = shouldAnimate ? controller.value : 1.0;
        return Column(
          children: [
            _ShimmerBar(widthFactor: 1, alignment: alignment, color: c.border),
            const SizedBox(height: 10),
            _ShimmerBar(
              widthFactor: 0.74,
              alignment: alignment,
              color: c.border,
            ),
            const SizedBox(height: 10),
            _ShimmerBar(
              widthFactor: 0.46,
              alignment: alignment,
              color: c.border,
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double widthFactor;
  final double alignment;
  final Color color;

  const _ShimmerBar({
    required this.widthFactor,
    required this.alignment,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.4 + alignment * 2.8, 0),
              end: Alignment(-0.2 + alignment * 2.8, 0),
              colors: [
                color.withValues(alpha: 0.58),
                Colors.white.withValues(alpha: 0.42),
                color.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingCardPreview extends StatefulWidget {
  const _MorphingCardPreview();

  @override
  State<_MorphingCardPreview> createState() => _MorphingCardPreviewState();
}

class _MorphingCardPreviewState extends State<_MorphingCardPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      expanded: _expanded,
      label: 'Alternar morphing de tarjeta',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration:
              shouldAnimate ? const Duration(milliseconds: 360) : Duration.zero,
          curve: Curves.easeOutBack,
          width: double.infinity,
          constraints: BoxConstraints(minHeight: _expanded ? 116 : 68),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _expanded
                ? AppColors.primary.withValues(alpha: 0.14)
                : c.surfaceVariant,
            borderRadius: BorderRadius.circular(_expanded ? 24 : 16),
            border: Border.all(
              color: _expanded ? AppColors.primary : c.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedDashboardSquare01,
                    color: _expanded ? AppColors.primary : c.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _expanded ? 'Estado expandido' : 'Tocá para transformar',
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: shouldAnimate
                    ? const Duration(milliseconds: 240)
                    : Duration.zero,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'La forma cambia, pero el objeto sigue siendo el mismo.',
                          style: TextStyle(color: c.textSecondary),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlipCardPreview extends StatefulWidget {
  const _FlipCardPreview();

  @override
  State<_FlipCardPreview> createState() => _FlipCardPreviewState();
}

class _FlipCardPreviewState extends State<_FlipCardPreview> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: 'Girar tarjeta 3D',
      child: GestureDetector(
        onTap: () => setState(() => _flipped = !_flipped),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _flipped ? 1 : 0),
          duration:
              shouldAnimate ? const Duration(milliseconds: 420) : Duration.zero,
          curve: Curves.easeInOutCubic,
          builder: (context, value, _) {
            final showBack = value > 0.5;
            final rotation = value * math.pi;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(rotation),
              child: Transform(
                alignment: Alignment.center,
                transform: showBack
                    ? (Matrix4.identity()..rotateY(math.pi))
                    : Matrix4.identity(),
                child: Container(
                  height: 112,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: showBack ? AppColors.info : c.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: showBack ? AppColors.info : c.border),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: showBack
                            ? HugeIcons.strokeRoundedAward01
                            : HugeIcons.strokeRoundedCreditCard,
                        color: showBack ? Colors.white : c.text,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          showBack
                              ? 'Reverso / QR / detalle'
                              : 'Frente de tarjeta',
                          style: TextStyle(
                            color: showBack ? Colors.white : c.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SwipeRevealPreview extends StatefulWidget {
  const _SwipeRevealPreview();

  @override
  State<_SwipeRevealPreview> createState() => _SwipeRevealPreviewState();
}

class _SwipeRevealPreviewState extends State<_SwipeRevealPreview> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final revealed = _drag > 42;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Container(
          height: 70,
          padding: const EdgeInsets.only(right: 18),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedAward01,
            color: AppColors.secondary,
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _drag = (_drag - details.delta.dx).clamp(0, 78);
            });
          },
          onHorizontalDragEnd: (_) {
            setState(() => _drag = revealed ? 72 : 0);
          },
          onTap: () => setState(() => _drag = revealed ? 0 : 72),
          child: AnimatedContainer(
            duration: shouldAnimate
                ? const Duration(milliseconds: 180)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(-_drag, 0, 0),
            height: 70,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    revealed ? 'Acción revelada' : 'Deslizá o tocá',
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  final bool replayKey;

  const _TimelinePreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    const labels = ['Enviar', 'Revisar', 'Aprobar'];

    return TweenAnimationBuilder<double>(
      key: ValueKey('timeline-$replayKey'),
      tween: Tween(begin: 0, end: 1),
      duration:
          shouldAnimate ? const Duration(milliseconds: 900) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          children: [
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      _TimelineDot(
                        active: value >= i / (labels.length - 1),
                        label: labels[i],
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final bool active;
  final String label;

  const _TimelineDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 34 : 28,
          height: active ? 34 : 28,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : c.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(color: active ? AppColors.accent : c.border),
          ),
          child: active
              ? const HugeIcon(
                  icon: HugeIcons.strokeRoundedAward01,
                  color: Colors.white,
                  size: 16,
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? c.text : c.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _WaveProgressPreview extends StatelessWidget {
  final AnimationController controller;
  final double progress;

  const _WaveProgressPreview({
    required this.controller,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 120,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                progress: progress,
                phase: shouldAnimate ? controller.value : 0,
                color: AppColors.secondary,
                trackColor: c.surfaceVariant,
                borderColor: c.border,
                textColor: c.text,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _StatusPulsePreview extends StatelessWidget {
  final AnimationController controller;

  const _StatusPulsePreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pulse =
            shouldAnimate ? Curves.easeInOut.transform(controller.value) : 0.0;
        return Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08 + pulse * 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.35 + pulse * 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14 + pulse * 8,
                height: 14 + pulse * 8,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Pendiente de revisión',
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypingPreview extends StatelessWidget {
  final bool replayKey;

  const _TypingPreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    const message = 'Tu siguiente paso está listo.';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: TweenAnimationBuilder<int>(
        key: ValueKey('typing-$replayKey'),
        tween: IntTween(begin: 0, end: message.length),
        duration:
            shouldAnimate ? const Duration(milliseconds: 950) : Duration.zero,
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return Text(
            message.substring(0, value),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _ParallaxPreview extends StatelessWidget {
  final AnimationController controller;

  const _ParallaxPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 118,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = shouldAnimate ? controller.value * math.pi * 2 : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              _DepthLayer(
                width: 190,
                height: 78,
                color: AppColors.primary.withValues(alpha: 0.12),
                borderColor: c.border,
                offset: Offset(math.sin(t) * 7, math.cos(t) * 3),
              ),
              _DepthLayer(
                width: 150,
                height: 70,
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderColor: c.border,
                offset: Offset(math.cos(t) * 11, math.sin(t) * 5),
              ),
              _DepthLayer(
                width: 104,
                height: 58,
                color: AppColors.accent.withValues(alpha: 0.22),
                borderColor: c.border,
                offset: Offset(math.sin(t + 1) * 15, math.cos(t + 1) * 8),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCompass01,
                  color: c.text,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DepthLayer extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final Color borderColor;
  final Offset offset;
  final Widget? child;

  const _DepthLayer({
    required this.width,
    required this.height,
    required this.color,
    required this.borderColor,
    required this.offset,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }
}

class _SnackbarPreview extends StatelessWidget {
  const _SnackbarPreview();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SacButton(
        text: 'Mostrar feedback',
        variant: SacButtonVariant.secondary,
        fullWidth: false,
        icon: HugeIcons.strokeRoundedAward01,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: const Text('Cambio guardado. Podés deshacerlo.'),
              action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
            ),
          );
        },
      ),
    );
  }
}

class _RadialMenuPreview extends StatefulWidget {
  const _RadialMenuPreview();

  @override
  State<_RadialMenuPreview> createState() => _RadialMenuPreviewState();
}

class _RadialMenuPreviewState extends State<_RadialMenuPreview> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final items = [
      (HugeIcons.strokeRoundedFiles01, AppColors.info, Offset(-70, -8)),
      (HugeIcons.strokeRoundedAward01, AppColors.accent, Offset(-48, -58)),
      (HugeIcons.strokeRoundedTarget01, AppColors.secondary, Offset(10, -68)),
    ];

    return SizedBox(
      height: 118,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          for (final item in items)
            AnimatedOpacity(
              duration: shouldAnimate
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              opacity: _open ? 1 : 0,
              child: AnimatedContainer(
                duration: shouldAnimate
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                curve: Curves.easeOutBack,
                transform: Matrix4.translationValues(
                  _open ? item.$3.dx : 0,
                  _open ? item.$3.dy : 0,
                  0,
                ),
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.$2.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: item.$2.withValues(alpha: 0.28)),
                ),
                child: HugeIcon(icon: item.$1, color: item.$2, size: 20),
              ),
            ),
          Semantics(
            button: true,
            expanded: _open,
            label: 'Abrir menú radial',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _open = !_open),
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.info.withValues(alpha: 0.22),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: _open ? math.pi / 4 : 0,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 76,
            bottom: 18,
            child: Text(
              _open ? 'Acciones abiertas' : 'Tocá para abrir',
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeUnlockPreview extends StatelessWidget {
  final bool replayKey;

  const _BadgeUnlockPreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      key: ValueKey('badge-$replayKey'),
      tween: Tween(begin: 0, end: 1),
      duration:
          shouldAnimate ? const Duration(milliseconds: 850) : Duration.zero,
      curve: Curves.elasticOut,
      builder: (context, value, _) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Transform.rotate(
                  angle: (1 - value) * -0.35,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedAward01,
                    color: AppColors.accent,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Insignia desbloqueada',
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardStackPreview extends StatelessWidget {
  final bool replayKey;

  const _CardStackPreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 130,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('stack-$replayKey'),
        tween: Tween(begin: 0, end: 1),
        duration:
            shouldAnimate ? const Duration(milliseconds: 700) : Duration.zero,
        curve: Curves.easeOutBack,
        builder: (context, value, _) {
          return Stack(
            children: [
              _StackedCard(
                offset: Offset(24 * value, 4),
                rotation: 0.08 * value,
                color: AppColors.info.withValues(alpha: 0.16),
                borderColor: c.border,
                label: 'Recursos',
              ),
              _StackedCard(
                offset: Offset(12 * value, 14 * value),
                rotation: -0.04 * value,
                color: AppColors.secondary.withValues(alpha: 0.16),
                borderColor: c.border,
                label: 'Clases',
              ),
              _StackedCard(
                offset: Offset.zero,
                rotation: 0,
                color: AppColors.primary.withValues(alpha: 0.14),
                borderColor: c.border,
                label: 'Dashboard',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StackedCard extends StatelessWidget {
  final Offset offset;
  final double rotation;
  final Color color;
  final Color borderColor;
  final String label;

  const _StackedCard({
    required this.offset,
    required this.rotation,
    required this.color,
    required this.borderColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 210,
          height: 86,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              label,
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicIslandPreview extends StatefulWidget {
  const _DynamicIslandPreview();

  @override
  State<_DynamicIslandPreview> createState() => _DynamicIslandPreviewState();
}

class _DynamicIslandPreviewState extends State<_DynamicIslandPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Center(
      child: Semantics(
        button: true,
        expanded: _expanded,
        label: 'Alternar Dynamic Island',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: shouldAnimate
                ? const Duration(milliseconds: 420)
                : Duration.zero,
            curve: Curves.easeOutBack,
            width: _expanded ? 264 : 138,
            height: _expanded ? 86 : 46,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF111111)
                  : const Color(0xFF141414),
              borderRadius: BorderRadius.circular(_expanded ? 28 : 999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: shouldAnimate
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              child: _expanded
                  ? Row(
                      key: const ValueKey('expanded-island'),
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedAward01,
                          color: AppColors.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Honor aprobado',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Abrir detalle',
                                style: TextStyle(
                                  color: Color(0xFFC8C8C8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('compact-island'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'En vivo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeshGradientPreview extends StatelessWidget {
  final AnimationController controller;

  const _MeshGradientPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 132,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _MeshGradientPainter(
                t: shouldAnimate ? controller.value : 0,
                borderColor: c.border,
                textColor: c.text,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _SpotlightBorderPreview extends StatefulWidget {
  const _SpotlightBorderPreview();

  @override
  State<_SpotlightBorderPreview> createState() =>
      _SpotlightBorderPreviewState();
}

class _SpotlightBorderPreviewState extends State<_SpotlightBorderPreview> {
  Offset _spotlight = const Offset(0.5, 0.5);

  void _updateSpotlight(Offset localPosition, Size size) {
    setState(() {
      _spotlight = Offset(
        (localPosition.dx / size.width).clamp(0.0, 1.0),
        (localPosition.dy / size.height).clamp(0.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 104);

        return GestureDetector(
          onPanDown: (details) => _updateSpotlight(details.localPosition, size),
          onPanUpdate: (details) =>
              _updateSpotlight(details.localPosition, size),
          onTapDown: (details) => _updateSpotlight(details.localPosition, size),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlight: _spotlight,
                surfaceColor: c.surfaceVariant,
                borderColor: c.border,
                accentColor: AppColors.primary,
              ),
              child: SizedBox(
                height: 104,
                child: Center(
                  child: Text(
                    'Tocá o arrastrá sobre el borde',
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HolographicFoilPreview extends StatelessWidget {
  final AnimationController controller;

  const _HolographicFoilPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = shouldAnimate ? controller.value : 0.0;
        return Container(
          height: 122,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, -1),
              end: Alignment(1 - t * 2, 1),
              colors: const [
                Color(0xFFFFF1EF),
                Color(0xFFE0F5EF),
                Color(0xFFFFF4E0),
                Color(0xFFEFF6FF),
                Color(0xFFFFF1EF),
              ],
              stops: const [0, 0.22, 0.48, 0.72, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCreditCard,
                color: AppColors.primaryDark,
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Credencial premium',
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoverflowPreview extends StatefulWidget {
  const _CoverflowPreview();

  @override
  State<_CoverflowPreview> createState() => _CoverflowPreviewState();
}

class _CoverflowPreviewState extends State<_CoverflowPreview> {
  late final PageController _controller;
  double _page = 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.58, initialPage: 1)
      ..addListener(() {
        if (!mounted) return;
        setState(() => _page = _controller.page ?? 1);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final items = [
      (AppColors.primary, 'Clase'),
      (AppColors.secondary, 'Honor'),
      (AppColors.info, 'Recurso'),
    ];

    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _controller,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final distance = (_page - index).clamp(-1.0, 1.0);
          final scale = 1 - distance.abs() * 0.16;
          final rotation = distance * -0.42;

          return Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(rotation),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: items[index].$1.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Center(
                  child: Text(
                    items[index].$2,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TextScramblePreview extends StatelessWidget {
  final bool replayKey;

  const _TextScramblePreview({required this.replayKey});

  static const _target = 'SACDIA-47A';
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('scramble-$replayKey'),
        tween: Tween(begin: 0, end: 1),
        duration:
            shouldAnimate ? const Duration(milliseconds: 1100) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final revealed = (_target.length * value).floor();
          final buffer = StringBuffer();

          for (var i = 0; i < _target.length; i++) {
            if (i < revealed || !shouldAnimate) {
              buffer.write(_target[i]);
            } else {
              buffer.write(
                  _chars[(i * 7 + (value * 41).floor()) % _chars.length]);
            }
          }

          return Text(
            buffer.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
        },
      ),
    );
  }
}

class _LineDrawingPreview extends StatelessWidget {
  final bool replayKey;

  const _LineDrawingPreview({required this.replayKey});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      height: 126,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('line-drawing-$replayKey'),
        tween: Tween(begin: 0, end: 1),
        duration:
            shouldAnimate ? const Duration(milliseconds: 1000) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _LineDrawingPainter(
                progress: value,
                color: AppColors.primary,
                mutedColor: c.border,
                textColor: c.text,
              ),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class _LiquidWipePreview extends StatefulWidget {
  const _LiquidWipePreview();

  @override
  State<_LiquidWipePreview> createState() => _LiquidWipePreviewState();
}

class _LiquidWipePreviewState extends State<_LiquidWipePreview> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: 'Alternar liquid wipe',
      child: GestureDetector(
        onTap: () => setState(() => _active = !_active),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _active ? 1 : 0),
          duration:
              shouldAnimate ? const Duration(milliseconds: 520) : Duration.zero,
          curve: Curves.easeInOutCubic,
          builder: (context, value, _) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: _LiquidWipePainter(
                  progress: value,
                  baseColor: c.surfaceVariant,
                  liquidColor: AppColors.info,
                  borderColor: c.border,
                  textColor: _active ? Colors.white : c.text,
                ),
                child: const SizedBox(height: 92, width: double.infinity),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DockMagnificationPreview extends StatefulWidget {
  const _DockMagnificationPreview();

  @override
  State<_DockMagnificationPreview> createState() =>
      _DockMagnificationPreviewState();
}

class _DockMagnificationPreviewState extends State<_DockMagnificationPreview> {
  int _selected = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final icons = [
      HugeIcons.strokeRoundedDashboardSquare01,
      HugeIcons.strokeRoundedFiles01,
      HugeIcons.strokeRoundedAward01,
      HugeIcons.strokeRoundedTarget01,
      HugeIcons.strokeRoundedCompass01,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < icons.length; i++)
            Semantics(
              button: true,
              selected: i == _selected,
              label: 'Seleccionar item ${i + 1}',
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: i == _selected ? 1.28 : 0.92,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == _selected ? AppColors.primary : c.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: HugeIcon(
                      icon: icons[i],
                      color: i == _selected ? Colors.white : c.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntelligentListPreview extends StatelessWidget {
  final AnimationController controller;

  const _IntelligentListPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shouldAnimate = !MediaQuery.of(context).disableAnimations;
    final baseItems = [
      (AppColors.error, 'Evidencia pendiente', 'alta'),
      (AppColors.accent, 'Clase por revisar', 'media'),
      (AppColors.secondary, 'Honor listo', 'baja'),
    ];

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final phase = shouldAnimate ? (controller.value * 3).floor() % 3 : 0;
        final items = [
          for (var i = 0; i < baseItems.length; i++)
            baseItems[(i + phase) % baseItems.length],
        ];

        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: items[i].$1.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: items[i].$1.withValues(alpha: 0.24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: items[i].$1,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i].$2,
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      items[i].$3,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double t;
  final Color borderColor;
  final Color textColor;

  const _MeshGradientPainter({
    required this.t,
    required this.borderColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawColor(const Color(0xFFF8FAFC), BlendMode.src);

    final blobs = [
      (
        AppColors.primary.withValues(alpha: 0.34),
        Offset(
          size.width * (0.20 + math.sin(t * math.pi * 2) * 0.08),
          size.height * 0.30,
        ),
        size.width * 0.42,
      ),
      (
        AppColors.secondary.withValues(alpha: 0.30),
        Offset(
          size.width * 0.76,
          size.height * (0.34 + math.cos(t * math.pi * 2) * 0.10),
        ),
        size.width * 0.46,
      ),
      (
        AppColors.accent.withValues(alpha: 0.28),
        Offset(
          size.width * (0.48 + math.cos(t * math.pi * 2) * 0.12),
          size.height * 0.82,
        ),
        size.width * 0.40,
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [blob.$1, blob.$1.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: blob.$2, radius: blob.$3),
        );
      canvas.drawCircle(blob.$2, blob.$3, paint);
    }

    canvas.restore();

    canvas.drawRRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Motion field',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(18, size.height - textPainter.height - 16),
    );
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.textColor != textColor;
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset spotlight;
  final Color surfaceColor;
  final Color borderColor;
  final Color accentColor;

  const _SpotlightPainter({
    required this.spotlight,
    required this.surfaceColor,
    required this.borderColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    final center =
        Offset(spotlight.dx * size.width, spotlight.dy * size.height);

    canvas.drawRRect(rect, Paint()..color = surfaceColor);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.24),
          accentColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 96));

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawCircle(center, 96, glowPaint);
    canvas.restore();

    canvas.drawRRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment(
            spotlight.dx * 2 - 1,
            spotlight.dy * 2 - 1,
          ),
          colors: [
            borderColor,
            accentColor.withValues(alpha: 0.82),
            borderColor,
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlight != spotlight ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.accentColor != accentColor;
  }
}

class _LineDrawingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color mutedColor;
  final Color textColor;

  const _LineDrawingPainter({
    required this.progress,
    required this.color,
    required this.mutedColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(18, size.height * 0.72)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.12,
        size.width * 0.48,
        size.height * 0.92,
        size.width * 0.70,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.06,
        size.width - 20,
        size.height * 0.48,
      );

    canvas.drawPath(
      path,
      Paint()
        ..color = mutedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      final animatedPath = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        animatedPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    final current = Offset(
      18 + (size.width - 38) * progress,
      size.height * (0.72 - math.sin(progress * math.pi) * 0.34),
    );

    canvas.drawCircle(current, 8, Paint()..color = color);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Ruta dibujada',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(18, size.height - 22));
  }

  @override
  bool shouldRepaint(covariant _LineDrawingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.textColor != textColor;
  }
}

class _LiquidWipePainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color liquidColor;
  final Color borderColor;
  final Color textColor;

  const _LiquidWipePainter({
    required this.progress,
    required this.baseColor,
    required this.liquidColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );

    canvas.drawRRect(rect, Paint()..color = baseColor);

    final x = size.width * progress;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(x, 0);

    for (double y = 0; y <= size.height; y += 8) {
      final waveX = x + math.sin(y / size.height * math.pi * 2) * 14;
      path.lineTo(waveX, y);
    }

    path
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawPath(path, Paint()..color = liquidColor);
    canvas.restore();

    canvas.drawRRect(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: progress > 0.5 ? 'Estado aplicado' : 'Tocá para transformar',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 32);

    textPainter.paint(
      canvas,
      Offset(16, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidWipePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.textColor != textColor;
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double phase;
  final Color color;
  final Color trackColor;
  final Color borderColor;
  final Color textColor;

  const _WavePainter({
    required this.progress,
    required this.phase,
    required this.color,
    required this.trackColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );

    final trackPaint = Paint()..color = trackColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(rect, trackPaint);

    final clippedProgress = progress.clamp(0.0, 1.0);
    final baseY = size.height * (1 - clippedProgress);
    final wavePath = Path()..moveTo(0, size.height);
    wavePath.lineTo(0, baseY);

    for (double x = 0; x <= size.width; x += 4) {
      final y = baseY +
          math.sin((x / size.width * math.pi * 2) + phase * math.pi * 2) * 8;
      wavePath.lineTo(x, y);
    }

    wavePath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawPath(wavePath, Paint()..color = color.withValues(alpha: 0.86));
    canvas.restore();
    canvas.drawRRect(rect, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(clippedProgress * 100).round()}%',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.textColor != textColor;
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(6.0, size.shortestSide * 0.10);
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

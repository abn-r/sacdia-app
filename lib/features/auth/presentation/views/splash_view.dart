import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/zarza_roja_credit.dart';
import 'package:sacdia_app/features/auth/presentation/widgets/sac_brand_mark.dart';

/// Splash de arranque. Navegación la resuelve GoRouter via redirect.
///
/// Primera impresión: logo nuevo centrado sobre blanco, fade+scale desde
/// [SacMotion.enterScale] (nunca desde 0). Reduced motion = solo opacidad.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _metaFade;

  @override
  void initState() {
    super.initState();

    // Rare / first-time: delight allowed, still under 500ms.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: SacMotion.easeOut),
    );

    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: SacMotion.easeOut),
      ),
    );

    _metaFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: SacMotion.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStatusWidget() {
    final bootstrapAsync = ref.watch(appBootstrapProvider);

    return bootstrapAsync.when(
      loading: () => const SacLoading(color: AppColors.loginBrandBlue),
      error: (_, __) => _buildErrorWidget('auth.error_unexpected'.tr()),
      data: (state) => switch (state) {
        AppBootstrapError(:final message) => _buildErrorWidget(message),
        _ => const SacLoading(color: AppColors.loginBrandBlue),
      },
    );
  }

  Widget _buildErrorWidget(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          color: Theme.of(context).colorScheme.error,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.sac.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => ref.read(appBootstrapProvider.notifier).retry(),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
          label: Text('common.retry'.tr()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = SacMotion.reduceMotionOf(context);

    Widget logo = const SacBrandMark(size: 128);

    if (!reduceMotion) {
      logo = FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: logo,
        ),
      );
    }

    final wordmark = Text(
      'SACDIA',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: context.sac.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.1,
          ),
    );

    return Scaffold(
      backgroundColor: context.sac.background,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                logo,
                const SizedBox(height: 28),
                reduceMotion
                    ? wordmark
                    : FadeTransition(opacity: _metaFade, child: wordmark),
                const SizedBox(height: 8),
                reduceMotion
                    ? const SacBrandHairline()
                    : FadeTransition(
                        opacity: _metaFade,
                        child: const SacBrandHairline(),
                      ),
                const SizedBox(height: 24),
                reduceMotion
                    ? _buildStatusWidget()
                    : FadeTransition(
                        opacity: _metaFade,
                        child: _buildStatusWidget(),
                      ),
              ],
            ),
            Positioned(
              bottom: 28,
              child: ZarzaRojaCredit(
                opacity: reduceMotion ? null : _metaFade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

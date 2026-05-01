import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/providers/app_bootstrap_provider.dart';

/// Vista de Splash Screen - Estilo "Scout Vibrante"
///
/// Fondo blanco con logo centrado, indicador de carga sutil con color
/// primario. La navegación es manejada automáticamente por GoRouter redirect.
class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildStatusWidget() {
    final bootstrapAsync = ref.watch(appBootstrapProvider);

    return bootstrapAsync.when(
      loading: () => const SacLoading(),
      error: (_, __) => _buildErrorWidget('auth.error_unexpected'.tr()),
      data: (state) => switch (state) {
        AppBootstrapError(:final message) => _buildErrorWidget(message),
        _ => const SacLoading(),
      },
    );
  }

  Widget _buildErrorWidget(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
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
          onPressed: () =>
              ref.read(appBootstrapProvider.notifier).retry(),
          icon: const Icon(Icons.refresh_rounded),
          label: Text('common.retry'.tr()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.sac.shadow,
                            blurRadius: 30,
                            spreadRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/img/LogoSACDIA.png',
                        width: 140,
                        height: 140,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'SACDIA',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: context.sac.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                  ),
                ),
                const SizedBox(height: 20),

                // Loading indicator or error/retry
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildStatusWidget(),
                ),
              ],
            ),

            // Footer text
            Positioned(
              bottom: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'by Sarza Roja',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.sac.textTertiary, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

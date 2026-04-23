import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/biometric_provider.dart';

/// Pantalla de bloqueo que se muestra en cada cold start cuando biometría
/// está habilitada.
///
/// Flujo:
/// 1. En `initState` se dispara el prompt biométrico.
/// 2. Si el usuario acierta → `biometricProvider.markUnlocked()` y
///    `BiometricGate` rendea los hijos normales.
/// 3. Si falla 3 veces → mostramos fallback: "Iniciar sesión con contraseña"
///    que cierra sesión y navega a `/login` (el router redirige solo).
///
/// NO almacena datos biométricos — solo rebota al backend nativo de local_auth.
class AppLockView extends ConsumerStatefulWidget {
  const AppLockView({super.key});

  @override
  ConsumerState<AppLockView> createState() => _AppLockViewState();
}

class _AppLockViewState extends ConsumerState<AppLockView> {
  static const int _maxAttempts = 3;

  int _failedAttempts = 0;
  bool _authenticating = false;
  bool _showPasswordFallback = false;

  @override
  void initState() {
    super.initState();
    // Primer intento automático al montar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuthenticate());
  }

  Future<void> _tryAuthenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final notifier = ref.read(biometricProvider.notifier);
    final ok = await notifier.authenticate(reason: 'biometric.unlock_reason'.tr());
    if (!mounted) return;
    if (ok) {
      // El notifier ya marcó `unlocked=true`; BiometricGate reacciona.
      setState(() => _authenticating = false);
      return;
    }
    _failedAttempts++;
    setState(() {
      _authenticating = false;
      _showPasswordFallback = _failedAttempts >= _maxAttempts;
    });
  }

  Future<void> _signOutAndGoToLogin() async {
    // AuthNotifier emite un nuevo AuthState → routerProvider redirecciona.
    await ref.read(authNotifierProvider.notifier).signOut();
    // Reseteamos también el estado biométrico efímero por higiene.
    if (!mounted) return;
    ref.read(biometricProvider.notifier).lock();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFingerPrintScan,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'biometric.unlock_title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'biometric.unlock_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _authenticating ? null : _tryAuthenticate,
                  icon: _authenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedFingerPrint,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: Text('biometric.authenticate_cta'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_showPasswordFallback) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _signOutAndGoToLogin,
                    child: Text('biometric.fallback_password'.tr()),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

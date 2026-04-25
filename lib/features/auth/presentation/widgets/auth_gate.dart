import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sac_loading.dart';

import '../providers/auth_providers.dart';
import '../../presentation/views/login_view.dart';
import '../../../home/presentation/views/home_view.dart';

/// Widget que controla la navegación entre Login y Home según estado de autenticación
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, _) {
        final authState = ref.watch(authNotifierProvider);

        return authState.when(
          loading: () => const Scaffold(
            body: Center(
              child: SacLoading(),
            ),
          ),
          error: (error, stackTrace) => Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    color: AppColors.error,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'auth.error_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(authNotifierProvider),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            ),
          ),
          data: (user) {
            if (user != null) {
              return const HomeView();
            }
            return const LoginView();
          },
        );
      },
    );
  }
}

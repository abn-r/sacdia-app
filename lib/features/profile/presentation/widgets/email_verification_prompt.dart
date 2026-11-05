import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/email_verification_remote_data_source.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

final emailVerificationDataSourceProvider =
    Provider<EmailVerificationRemoteDataSource>((ref) {
  return EmailVerificationRemoteDataSource(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

/// Profile card shown while the account email is unconfirmed. Tapping it
/// emails a new link; if the server says the email is already verified, the
/// user is reloaded and the card goes away.
class EmailVerificationPrompt extends ConsumerStatefulWidget {
  const EmailVerificationPrompt({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  ConsumerState<EmailVerificationPrompt> createState() =>
      _EmailVerificationPromptState();
}

class _EmailVerificationPromptState
    extends ConsumerState<EmailVerificationPrompt> {
  bool _sending = false;

  Future<void> _resend(String email) async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(emailVerificationDataSourceProvider).send();
      if (result == EmailVerificationSendResult.alreadyVerified) {
        await ref
            .read(authNotifierProvider.notifier)
            .refreshCurrentUser(keepCurrentOnFailure: true);
        SacSnackBar.showMessenger(
          messenger,
          'profile.email_verification.already_verified'.tr(),
        );
      } else {
        SacSnackBar.showMessenger(
          messenger,
          'profile.email_verification.sent'.tr(namedArgs: {'email': email}),
        );
      }
    } on EmailVerificationSendException catch (e) {
      SacSnackBar.showMessenger(
        messenger,
        (e.reason == EmailVerificationSendError.tooManyRequests
                ? 'profile.email_verification.too_many'
                : 'profile.email_verification.error')
            .tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(
      authNotifierProvider.select((value) => value.value),
    );
    final email = user?.email;
    if (user == null || email == null || !user.needsEmailVerification) {
      return const SizedBox.shrink();
    }
    final c = context.sac;
    final theme = Theme.of(context);

    // An amber banner with its own room: it asks for an action, so it should
    // not read as one more card stuck to Información médica.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        4,
        widget.horizontalPadding,
        20,
      ),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.warningContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMailAtSign01,
                    size: 20,
                    color: c.onWarningContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'profile.email_verification.title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.onWarningContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.onWarningContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: SacLoadingSmall(),
                    ),
                  )
                else
                  TextButton(
                    key: const ValueKey('email-verification-send'),
                    onPressed: () => _resend(email),
                    style: TextButton.styleFrom(
                      backgroundColor: c.surface,
                      foregroundColor: c.onWarningContainer,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text('profile.email_verification.send_link'.tr()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

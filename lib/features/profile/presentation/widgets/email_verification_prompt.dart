import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/email_verification_remote_data_source.dart';
import 'setting_tile.dart';

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
      authNotifierProvider.select((value) => value.valueOrNull),
    );
    final email = user?.email;
    if (user == null || email == null || !user.needsEmailVerification) {
      return const SizedBox.shrink();
    }
    final c = context.sac;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        12,
        widget.horizontalPadding,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1),
        ),
        child: SettingTile(
          icon: HugeIcons.strokeRoundedMail01,
          title: 'profile.email_verification.title'.tr(),
          subtitle: 'profile.email_verification.subtitle'
              .tr(namedArgs: {'email': email}),
          trailing: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _sending ? null : () => _resend(email),
        ),
      ),
    );
  }
}

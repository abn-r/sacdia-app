import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/forbidden.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/service_credential.dart';
import '../providers/service_credentials_providers.dart';
import '../widgets/my_credentials_body.dart';
import '../widgets/service_credential_confirm_sheet.dart';
import '../widgets/service_credentials_skeleton.dart';

/// «Mis constancias»: the state of the person's current counselor credential
/// as a panel, its document, the action that fits it (withdraw, resubmit or
/// upload another) and the older ones in «Historial».
class MyServiceCredentialsView extends ConsumerWidget {
  const MyServiceCredentialsView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myServiceCredentialsProvider);
    try {
      await ref.read(myServiceCredentialsProvider.future);
    } catch (_) {
      // The list renders its own error state.
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    ServiceCredential credential,
  ) async {
    final confirmed = await showServiceCredentialConfirmSheet(
      context,
      title: 'service_credentials.withdraw.title'.tr(),
      body: 'service_credentials.withdraw.body'.tr(),
      confirmLabel: 'service_credentials.withdraw.confirm'.tr(),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final failure = await ref
        .read(serviceCredentialWithdrawProvider.notifier)
        .withdraw(credential.id);
    if (!context.mounted) return;
    SacSnackBar.show(
      context,
      failure == null
          ? 'service_credentials.withdraw.done'.tr()
          : userErrorMessage(failure),
      isSuccess: failure == null,
      isError: failure != null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final async = ref.watch(myServiceCredentialsProvider);
    final withdrawing = ref.watch(serviceCredentialWithdrawProvider);
    final items = async.hasError ? null : async.value;
    // The current credential is the newest one; only a rejected one offers
    // to upload again from the footer.
    final current = items == null || items.isEmpty ? null : items.first;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'service_credentials.mine.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      bottomNavigationBar: current != null && current.isRejected
          ? SacFrostedFooter(
              child: SacButton.primary(
                key: const ValueKey('credential-resubmit'),
                text: 'service_credentials.row.resubmit'.tr(),
                icon: HugeIcons.strokeRoundedUpload01,
                onPressed: () => _upload(context),
              ),
            )
          : null,
      body: async.when(
        loading: () => const ServiceCredentialsSkeleton(),
        error: (error, _) => isForbiddenFailure(error)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'service_credentials.mine.error_title'.tr(),
                message: userErrorMessage(error),
                onRetry: () => ref.invalidate(myServiceCredentialsProvider),
              ),
        data: (items) => RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: () => _refresh(ref),
          child: items.isEmpty
              ? _EmptyBody(onUpload: () => _upload(context))
              : MyCredentialsBody(
                  items: items,
                  withdrawing: withdrawing,
                  onUpload: () => _upload(context),
                  onWithdraw: (item) => _withdraw(context, ref, item),
                ),
        ),
      ),
    );
  }

  static void _upload(BuildContext context) =>
      context.push(RouteNames.serviceCredentialsNew);
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SacEmptyState(
            icon: HugeIcons.strokeRoundedCertificate01,
            title: 'service_credentials.mine.empty_title'.tr(),
            body: 'service_credentials.mine.empty_body'.tr(),
            actionLabel: 'service_credentials.mine.upload'.tr(),
            actionIcon: HugeIcons.strokeRoundedUpload01,
            onAction: onUpload,
          ),
        ),
      ],
    );
  }
}

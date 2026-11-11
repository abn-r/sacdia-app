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
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../members/presentation/widgets/join_request_group.dart';
import '../../domain/entities/service_credential.dart';
import '../providers/service_credentials_providers.dart';
import '../widgets/service_credential_row.dart';
import '../widgets/service_credentials_skeleton.dart';

/// «Mis constancias»: the person's own counselor credentials grouped by status
/// (En revisión, Aprobadas, Rechazadas), with upload, withdraw and resubmit.
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
    final confirmed = await SacDialog.show(
      context,
      title: 'service_credentials.withdraw.title'.tr(),
      content: 'service_credentials.withdraw.body'.tr(),
      confirmLabel: 'service_credentials.withdraw.confirm'.tr(),
      cancelLabel: 'common.cancel'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true) return;
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
    // One pending credential at a time: the server answers
    // SERVICE_CREDENTIAL_PENDING_EXISTS to a second one.
    final canUpload =
        items != null && items.isNotEmpty && !items.any((i) => i.isPending);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'service_credentials.mine.title'.tr()),
      bottomNavigationBar: canUpload
          ? SacPinnedActionBar(
              child: SacButton.primary(
                text: 'service_credentials.mine.upload'.tr(),
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
              : _Body(
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

class _Body extends StatelessWidget {
  const _Body({
    required this.items,
    required this.withdrawing,
    required this.onUpload,
    required this.onWithdraw,
  });

  final List<ServiceCredential> items;
  final Set<String> withdrawing;
  final VoidCallback onUpload;
  final void Function(ServiceCredential item) onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = items.where((i) => i.isPending).toList();
    final approved = items.where((i) => i.isApproved).toList();
    final rejected = items.where((i) => i.isRejected).toList();

    Widget group(
      String titleKey,
      Color dot,
      List<ServiceCredential> group, {
      bool resubmit = false,
    }) =>
        JoinRequestGroupSection(
          title: titleKey.tr(),
          count: group.length,
          dotColor: dot,
          children: [
            for (final item in group)
              ServiceCredentialRow(
                key: ValueKey('service-credential-${item.id}'),
                credential: item,
                isWithdrawing: withdrawing.contains(item.id),
                onWithdraw: () => onWithdraw(item),
                onResubmit: resubmit ? onUpload : null,
              ),
          ],
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'service_credentials.mine.intro'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            color: c.textSecondary,
            height: 1.35,
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          SacNotice(
            key: const ValueKey('pending-notice'),
            text: 'service_credentials.mine.pending_note'.tr(),
            icon: HugeIcons.strokeRoundedClock01,
          ),
        ],
        const SizedBox(height: 24),
        if (pending.isNotEmpty) ...[
          group('service_credentials.group.pending', c.warning, pending),
          const SizedBox(height: 20),
        ],
        if (rejected.isNotEmpty) ...[
          group('service_credentials.group.rejected', c.error, rejected,
              resubmit: true),
          const SizedBox(height: 20),
        ],
        if (approved.isNotEmpty)
          group('service_credentials.group.approved', c.success, approved),
      ],
    );
  }
}

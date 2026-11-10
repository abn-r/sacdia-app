import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/config/access_denied_view.dart';
import '../../../../core/errors/forbidden.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_pdf_viewer.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../providers/service_credentials_providers.dart';
import '../utils/service_credential_labels.dart';
import '../utils/service_credentials_access.dart';
import '../widgets/review_decision_sheets.dart';
import '../widgets/service_credential_status_pill.dart';
import '../widgets/service_credentials_skeleton.dart';

/// Detail of one credential under review: who and which club, what and when,
/// the file (image inline, PDF in the app viewer) and, while pending, the
/// decision: Aprobar (optional expiry) or Rechazar (reason required).
class ServiceCredentialReviewDetailView extends ConsumerWidget {
  const ServiceCredentialReviewDetailView({super.key, required this.id});

  final String id;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final choice = await showApproveCredentialSheet(context);
    if (choice == null) return;
    final failure = await ref
        .read(serviceCredentialReviewActionsProvider.notifier)
        .approve(id, expiresAt: choice.expiresAt);
    if (!context.mounted) return;
    _finish(context, failure, 'service_credentials.review.approved_done'.tr());
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectCredentialSheet(context);
    if (reason == null) return;
    final failure = await ref
        .read(serviceCredentialReviewActionsProvider.notifier)
        .reject(id, reason: reason);
    if (!context.mounted) return;
    _finish(context, failure, 'service_credentials.review.rejected_done'.tr());
  }

  /// Success: say so and go back to the queue (already invalidated). Failure
  /// (including «ya fue revisada»): say why and stay; the detail reloads.
  void _finish(BuildContext context, Object? failure, String doneMessage) {
    SacSnackBar.show(
      context,
      failure == null ? doneMessage : userErrorMessage(failure),
      isSuccess: failure == null,
      isError: failure != null,
    );
    if (failure == null && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canReviewServiceCredentialsProvider)) {
      return const AccessDeniedView();
    }
    final c = context.sac;
    final async = ref.watch(reviewDetailProvider(id));
    final busy = ref.watch(serviceCredentialReviewActionsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(title: 'service_credentials.review.detail_title'.tr()),
      body: async.when(
        loading: () => const ServiceCredentialsSkeleton(rowCount: 3),
        error: (error, _) => isForbiddenFailure(error)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'service_credentials.review.detail_error_title'.tr(),
                message: userErrorMessage(error),
                onRetry: () => ref.invalidate(reviewDetailProvider(id)),
              ),
        data: (detail) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _Header(detail: detail),
            const SizedBox(height: 16),
            _FileSection(detail: detail),
            if (detail.item.status == ServiceCredentialStatus.rejected &&
                detail.decisionReason != null) ...[
              const SizedBox(height: 16),
              _Note(
                text: tr('service_credentials.row.rejected_reason',
                    namedArgs: {'reason': detail.decisionReason!}),
                color: c.error,
              ),
            ],
            if (detail.item.status == ServiceCredentialStatus.approved &&
                detail.expiresAt != null) ...[
              const SizedBox(height: 16),
              _Note(
                text: tr('service_credentials.row.valid_until', namedArgs: {
                  'date': serviceCredentialDate(context, detail.expiresAt!),
                }),
                color: c.textSecondary,
              ),
            ],
            if (detail.item.status == ServiceCredentialStatus.pendingReview ||
                detail.item.status == ServiceCredentialStatus.unknown) ...[
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'service_credentials.review.approve'.tr(),
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                isLoading: busy,
                onPressed: busy ? null : () => _approve(context, ref),
              ),
              const SizedBox(height: 8),
              SacButton.outline(
                text: 'service_credentials.review.reject'.tr(),
                icon: HugeIcons.strokeRoundedCancelCircle,
                onPressed: busy ? null : () => _reject(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final ReviewDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final item = detail.item;
    final name = item.person.name.trim().isEmpty
        ? 'service_credentials.review.unknown_person'.tr()
        : item.person.name.trim();
    final completed = item.completedAt;
    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SacMemberAvatar(
                imageUrl: item.person.photoUrl,
                name: name,
                semanticLabel: name,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (item.clubName != null)
                      Text(
                        item.clubName!,
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ServiceCredentialStatusPill(status: item.status),
            ],
          ),
          const SizedBox(height: 16),
          _Fact(
            label: 'service_credentials.review.fact_credential'.tr(),
            value: serviceCredentialTitle(),
          ),
          if (completed != null)
            _Fact(
              label: 'service_credentials.review.fact_completed'.tr(),
              value: serviceCredentialDate(context, completed),
            ),
          if (item.createdAt != null)
            _Fact(
              label: 'service_credentials.review.fact_sent'.tr(),
              value: serviceCredentialDate(context, item.createdAt!),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          color: color,
          height: 1.35,
        ),
      );
}

/// File of the credential. Images preview inline (signed URL, no disk cache);
/// a PDF shows a card that opens the app's PDF viewer. Both open full screen.
class _FileSection extends StatelessWidget {
  const _FileSection({required this.detail});

  final ReviewDetail detail;

  void _open(BuildContext context) {
    final url = detail.fileUrl;
    if (url == null) return;
    final title = detail.item.person.name;
    Navigator.of(context).push<void>(
      SacFadeThroughRoute<void>(
        builder: (_) => detail.isPdf
            ? SacPdfViewer(pdfSource: url, title: title, allowShare: false)
            : SacImageViewer(
                imageUrl: url,
                title: title,
                allowShare: false,
                cacheNetwork: false,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    if (!detail.hasFile) {
      return _Note(
        text: 'service_credentials.review.no_file'.tr(),
        color: c.textSecondary,
      );
    }
    final fileCard = SacCard(
      onTap: () => _open(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.light,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Center(
              child: HugeIcon(
                icon: detail.isPdf
                    ? HugeIcons.strokeRoundedPdf01
                    : HugeIcons.strokeRoundedImage01,
                size: 24,
                color: accent.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'service_credentials.review.open_file'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 18,
            color: c.textTertiary,
          ),
        ],
      ),
    );
    if (!detail.isImage) return fileCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'service_credentials.review.open_file'.tr(),
          child: GestureDetector(
            onTap: () => _open(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.network(
                  detail.fileUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        fileCard,
      ],
    );
  }
}

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
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_image_viewer.dart';
import '../../../../core/widgets/sac_pdf_viewer.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/sac_value_row.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../providers/service_credentials_providers.dart';
import '../utils/service_credential_labels.dart';
import '../utils/service_credential_status_style.dart';
import '../utils/service_credentials_access.dart';
import '../widgets/review_decision_sheets.dart';
import '../widgets/service_credential_text_row.dart';
import '../widgets/service_credentials_skeleton.dart';

/// Detail of one credential under review: the file first (image inline, PDF in
/// the app viewer), then who, which club and when, and, while pending, the
/// decision fixed at the bottom: Rechazar or Aprobar (optional expiry; the
/// rejection needs a reason).
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
    final detail = async.value;
    final isPending = detail != null &&
        (detail.item.status == ServiceCredentialStatus.pendingReview ||
            detail.item.status == ServiceCredentialStatus.unknown);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'service_credentials.review.detail_title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      bottomNavigationBar: isPending
          ? SacFrostedFooter(
              child: Row(
                children: [
                  Expanded(
                    child: SacButton.outline(
                      key: const ValueKey('review-reject'),
                      text: 'service_credentials.review.reject'.tr(),
                      onPressed: busy ? null : () => _reject(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SacButton.primary(
                      key: const ValueKey('review-approve'),
                      text: 'service_credentials.review.approve'.tr(),
                      isLoading: busy,
                      onPressed: busy ? null : () => _approve(context, ref),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: async.when(
        loading: () => const ServiceCredentialsSkeleton(rowCount: 3),
        error: (error, _) => isForbiddenFailure(error)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'service_credentials.review.detail_error_title'.tr(),
                message: userErrorMessage(error),
                onRetry: () => ref.invalidate(reviewDetailProvider(id)),
              ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ReviewDetail detail;

  @override
  Widget build(BuildContext context) {
    final item = detail.item;
    final name = item.person.name.trim().isEmpty
        ? 'service_credentials.review.unknown_person'.tr()
        : item.person.name.trim();
    final club = item.clubName?.trim();
    final completed = item.completedAt;
    final sent = item.createdAt;
    final reviewed = item.reviewedAt;
    final expires = detail.expiresAt;
    final reason = detail.decisionReason?.trim();
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _FileSection(detail: detail),
        ),
        SacGroupedSection(
          key: const ValueKey('review-data'),
          label: 'service_credentials.review.data_label'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 16,
          children: [
            SacValueRow(
              label: 'service_credentials.review.fact_person'.tr(),
              value: name,
            ),
            if (club != null && club.isNotEmpty)
              SacValueRow(
                label: 'service_credentials.review.fact_club'.tr(),
                value: club,
              ),
            SacValueRow(
              label: 'service_credentials.review.fact_status'.tr(),
              value: serviceCredentialStatusLabel(item.status),
            ),
            if (completed != null)
              SacValueRow(
                label: 'service_credentials.review.fact_completed'.tr(),
                value: serviceCredentialDate(context, completed),
              ),
            if (sent != null)
              SacValueRow(
                label: 'service_credentials.review.fact_sent'.tr(),
                value: serviceCredentialDate(context, sent),
              ),
            if (reviewed != null)
              SacValueRow(
                label: 'service_credentials.review.fact_reviewed'.tr(),
                value: serviceCredentialDate(context, reviewed),
              ),
            if (item.status == ServiceCredentialStatus.approved &&
                expires != null)
              SacValueRow(
                label: 'service_credentials.review.fact_valid_until'.tr(),
                value: serviceCredentialDate(context, expires),
              ),
          ],
        ),
        if (item.status == ServiceCredentialStatus.rejected &&
            reason != null &&
            reason.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('review-reason'),
            label: 'service_credentials.review.reason_label'.tr(),
            action: const SizedBox.shrink(),
            dividerIndent: 0,
            children: [ServiceCredentialTextRow(text: reason)],
          ),
      ],
    );
  }
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
      return Text(
        'service_credentials.review.no_file'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          color: c.textSecondary,
          height: 1.35,
        ),
      );
    }
    final fileCard = SacCard(
      key: const ValueKey('review-file-card'),
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
                  fit: BoxFit.contain,
                  width: double.infinity,
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

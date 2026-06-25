import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/presentation/providers/club_selection_providers.dart';
import '../../../post_registration/presentation/views/club_selection_step_view.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/transfer_request.dart';
import '../providers/transfer_providers.dart';

/// Pantalla principal de solicitudes de traslado.
///
/// Muestra:
///  - Lista de mis solicitudes con estado
///  - FAB para crear nueva solicitud
class TransferRequestsView extends ConsumerWidget {
  const TransferRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myTransferRequestsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr('transfers.list.title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => _ErrorBody(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(myTransferRequestsProvider),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return _EmptyBody(
              onNewRequest: () => _openNewRequest(context),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myTransferRequestsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TransferCard(
                request: requests[i],
                onTap: () => context.push(
                  RouteNames.transferRequestDetail(requests[i].id),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewRequest(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          'transfers.list.new_request'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _openNewRequest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransferRequestFormView(),
      ),
    );
  }
}

// ── Transfer card ─────────────────────────────────────────────────────────────

class _TransferCard extends StatelessWidget {
  final TransferRequest request;
  final VoidCallback? onTap;

  const _TransferCard({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusConfig = _statusConfig(request.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Icon ────────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusConfig.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: HugeIcon(
                  icon: statusConfig.icon,
                  color: statusConfig.fg,
                  size: 18,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request.toClubName != null)
                    Text(
                      request.toClubName!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (request.toSectionName != null)
                    Text(
                      request.toSectionName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      tr('transfers.list.section_number',
                          namedArgs: {'id': '${request.toSectionId}'}),
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Status badge ─────────────────────────────────────────
            _StatusBadge(status: request.status),
          ],
        ),
      ),
    );
  }

  _TransferStatusConfig _statusConfig(TransferStatus status) {
    switch (status) {
      case TransferStatus.approved:
        return _TransferStatusConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case TransferStatus.rejected:
        return _TransferStatusConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
          icon: HugeIcons.strokeRoundedCancel01,
        );
      case TransferStatus.pending:
        return _TransferStatusConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
          icon: HugeIcons.strokeRoundedClock01,
        );
    }
  }
}

class _TransferStatusConfig {
  final Color bg;
  final Color fg;
  final dynamic icon;

  const _TransferStatusConfig({
    required this.bg,
    required this.fg,
    required this.icon,
  });
}

class _StatusBadge extends StatelessWidget {
  final TransferStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case TransferStatus.approved:
        bg = AppColors.secondaryLight;
        fg = AppColors.secondaryDark;
        break;
      case TransferStatus.rejected:
        bg = AppColors.errorLight;
        fg = AppColors.errorDark;
        break;
      case TransferStatus.pending:
        bg = AppColors.accentLight;
        fg = AppColors.accentDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  final VoidCallback? onNewRequest;

  const _EmptyBody({this.onNewRequest});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedExchange01,
              color: c.textTertiary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              tr('transfers.list.empty_title'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('transfers.list.empty_subtitle'),
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: tr('transfers.list.empty_action'),
              icon: HugeIcons.strokeRoundedAdd01,
              onPressed: onNewRequest,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SacButton.primary(
              text: tr('common.retry'),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form view (same file for compactness) ────────────────────────────────────

/// Formulario para crear una nueva solicitud de traslado.
class TransferRequestFormView extends ConsumerStatefulWidget {
  const TransferRequestFormView({super.key});

  @override
  ConsumerState<TransferRequestFormView> createState() =>
      _TransferRequestFormViewState();
}

class _TransferRequestFormViewState
    extends ConsumerState<TransferRequestFormView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetSelection());
  }

  void _resetSelection() {
    if (!mounted) return;
    ref.invalidate(selectedCountryProvider);
    ref.invalidate(selectedUnionProvider);
    ref.invalidate(selectedLocalFieldProvider);
    ref.invalidate(selectedClubProvider);
    ref.invalidate(requiredClubTypeIdProvider);
    _syncRequiredClubType();
  }

  void _syncRequiredClubType() {
    final activeGrant =
        ref.read(authNotifierProvider).valueOrNull?.authorization?.activeGrant;
    final clubTypeId = activeGrant?.clubTypeId;
    if (clubTypeId == null) return;
    ref.read(requiredClubTypeIdProvider.notifier).state = clubTypeId;
  }

  Future<void> _submit() async {
    final activeGrant =
        ref.read(authNotifierProvider).valueOrNull?.authorization?.activeGrant;
    final fromSectionId = activeGrant?.sectionId;
    final toSectionId = ref.read(selectedClubSectionProvider);

    if (fromSectionId == null || toSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('transfers.form.select_valid_club'.tr()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final notifier = ref.read(createTransferProvider.notifier);
    final success = await notifier.create(
      fromSectionId: fromSectionId,
      toSectionId: toSectionId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('transfers.form.success_message'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(createTransferProvider);
    final activeGrant = ref.watch(
      authNotifierProvider.select(
        (value) => value.valueOrNull?.authorization?.activeGrant,
      ),
    );
    final currentClassName =
        ref.watch(profileNotifierProvider).valueOrNull?.currentClass;
    final selectedSectionId = ref.watch(selectedClubSectionProvider);
    final requiredClubTypeId = ref.watch(requiredClubTypeIdProvider);
    final c = context.sac;

    final activeClubTypeId = activeGrant?.clubTypeId;
    if (activeClubTypeId != null && requiredClubTypeId != activeClubTypeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(requiredClubTypeIdProvider.notifier).state = activeClubTypeId;
      });
    }

    final fromSectionId = activeGrant?.sectionId;
    final canSubmit = fromSectionId != null &&
        selectedSectionId != null &&
        selectedSectionId != fromSectionId &&
        !formState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr('transfers.form.title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: activeGrant == null || activeClubTypeId == null
          ? _ErrorBody(
              message: 'transfers.form.no_active_membership'.tr(),
              onRetry: () => ref
                  .read(authNotifierProvider.notifier)
                  .refreshCurrentUser(keepCurrentOnFailure: true),
            )
          : Column(
              children: [
                Expanded(
                  child: ClubSelectionStepView(
                    isClubTransfer: true,
                    preservedClassName: currentClassName,
                  ),
                ),
                if (formState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _InlineError(message: formState.errorMessage!),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SacButton.primary(
                      text: tr('transfers.form.submit'),
                      icon: HugeIcons.strokeRoundedSent,
                      isLoading: formState.isLoading,
                      onPressed: canSubmit ? _submit : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: AppColors.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

/// CTA de Pedidos en el detalle del camporee. Oculto si no hay settings o
/// la sección no está inscrita.
class CamporeeOrdersCta extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;
  final bool embedded;

  const CamporeeOrdersCta({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(camporeeId));
    final enrolled = camporeeParticipantsAreEnabled(registrationAsync);
    if (!enrolled) return const SizedBox.shrink();

    final scope = CamporeeOrdersScope(
      camporeeId: camporeeId,
      type: camporeeType,
    );
    final offeringsAsync = ref.watch(camporeeOrderOfferingsProvider(scope));

    return offeringsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) {
        final code = error is Failure ? error.code : null;
        final cta = resolveCamporeeOrdersCtaState(
          sectionEnrolled: true,
          offeringsErrorCode: code,
        );
        if (cta == CamporeeOrdersCtaState.hidden) {
          return const SizedBox.shrink();
        }
        return _CtaButton(
          state: cta,
          camporeeId: camporeeId,
          camporeeType: camporeeType,
          embedded: embedded,
        );
      },
      data: (catalog) {
        final cta = resolveCamporeeOrdersCtaState(
          sectionEnrolled: true,
          settings: catalog.settings,
        );
        if (cta == CamporeeOrdersCtaState.hidden) {
          return const SizedBox.shrink();
        }
        return _CtaButton(
          state: cta,
          camporeeId: camporeeId,
          camporeeType: camporeeType,
          embedded: embedded,
        );
      },
    );
  }
}

class _CtaButton extends StatelessWidget {
  final CamporeeOrdersCtaState state;
  final int camporeeId;
  final CamporeeKind camporeeType;
  final bool embedded;

  const _CtaButton({
    required this.state,
    required this.camporeeId,
    required this.camporeeType,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state == CamporeeOrdersCtaState.open;
    final closedHint = state == CamporeeOrdersCtaState.notOpen
        ? 'camporee_orders.cta.not_open'.tr()
        : 'camporee_orders.cta.closed'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded) const SizedBox(height: 16),
        SacButton(
          key: const Key('camporee-orders-cta'),
          text: 'camporee_orders.cta.label'.tr(),
          icon: HugeIcons.strokeRoundedShoppingBag01,
          variant:
              embedded ? SacButtonVariant.outline : SacButtonVariant.primary,
          isEnabled: enabled,
          fullWidth: true,
          onPressed: enabled
              ? () => context.push(
                    RouteNames.camporeeOrdersPath(
                      camporeeId,
                      type: camporeeType == CamporeeKind.union
                          ? 'union'
                          : 'local',
                    ),
                  )
              : null,
          labelMaxLines: 2,
          labelOverflow: TextOverflow.visible,
        ),
        if (!enabled) ...[
          const SizedBox(height: 8),
          Text(
            closedHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              color: context.sac.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Historial de pedidos de la sección + acceso a emitir otro folio.
class CamporeeOrderCatalogView extends ConsumerWidget {
  final int camporeeId;
  final CamporeeKind camporeeType;

  const CamporeeOrderCatalogView({
    super.key,
    required this.camporeeId,
    this.camporeeType = CamporeeKind.local,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = CamporeeOrdersScope(
      camporeeId: camporeeId,
      type: camporeeType,
    );
    final offeringsAsync = ref.watch(camporeeOrderOfferingsProvider(scope));
    final ordersAsync = ref.watch(camporeeOrdersListProvider(scope));
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'camporee_orders.catalog.title'.tr(),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: RefreshIndicator(
              color: SacAccent.of(context).color,
              onRefresh: () async {
                ref.invalidate(camporeeOrderOfferingsProvider(scope));
                ref.invalidate(camporeeOrdersListProvider(scope));
              },
              child: offeringsAsync.when(
                loading: () => const Center(child: SacLoading()),
                error: (error, _) => SacErrorState(
                  scrollable: true,
                  title: '',
                  message: camporeeOrdersErrorMessage(error),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                  onRetry: () =>
                      ref.invalidate(camporeeOrderOfferingsProvider(scope)),
                ),
                data: (catalog) => _CatalogBody(
                  scope: scope,
                  catalog: catalog,
                  ordersAsync: ordersAsync,
                  onRetryOrders: () =>
                      ref.invalidate(camporeeOrdersListProvider(scope)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogBody extends ConsumerWidget {
  final CamporeeOrdersScope scope;
  final CamporeeOrderOfferingsCatalog catalog;
  final AsyncValue<List<CamporeeOrder>> ordersAsync;
  final VoidCallback onRetryOrders;

  const _CatalogBody({
    required this.scope,
    required this.catalog,
    required this.ordersAsync,
    required this.onRetryOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final window = evaluateCamporeeOrdersWindow(catalog.settings);
    final canCreate = window == CamporeeOrdersWindow.open;

    if (window == CamporeeOrdersWindow.disabled) {
      return SacEmptyState(
        scrollable: true,
        icon: HugeIcons.strokeRoundedCancel01,
        title: 'camporee_orders.catalog.disabled'.tr(),
      );
    }

    return ListView(
      padding: SacTopBar.paddingBelowBar(
          context, const EdgeInsets.fromLTRB(20, 16, 20, 40)),
      children: [
        if (window == CamporeeOrdersWindow.notOpen)
          _Banner(
            text: 'camporee_orders.catalog.not_open'.tr(),
            color: AppColors.warning,
          ),
        if (window == CamporeeOrdersWindow.closed)
          _Banner(
            text: 'camporee_orders.catalog.closed'.tr(),
            color: AppColors.warning,
          ),
        if (window != CamporeeOrdersWindow.open) const SizedBox(height: 16),
        SacButton.primary(
          key: const Key('camporee-orders-new'),
          text: 'camporee_orders.catalog.new_order'.tr(),
          icon: HugeIcons.strokeRoundedShoppingCartAdd01,
          isEnabled: canCreate,
          onPressed: canCreate
              ? () {
                  ref.read(camporeeOrderDraftProvider(scope).notifier).clear();
                  context.push(
                    RouteNames.camporeeOrdersCapturePath(
                      scope.camporeeId,
                      type: scope.typeQuery,
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 24),
        Text(
          'camporee_orders.catalog.history_title'.tr(),
          style: TextStyle(
            fontSize: SacFontSize.titleMedium,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        ordersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: SacLoading()),
          ),
          error: (error, _) => SacErrorState.inline(
            message: camporeeOrdersErrorMessage(error),
            onRetry: onRetryOrders,
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'camporee_orders.catalog.empty'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: SacFontSize.titleSmall, color: c.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                for (final order in orders) ...[
                  _OrderHistoryCard(
                    order: order,
                    onTap: () => context.push(
                      RouteNames.camporeeOrderDetailPath(order.orderId),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final CamporeeOrder order;
  final VoidCallback onTap;

  const _OrderHistoryCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: SacInkWell(
        key: Key('camporee-order-folio-${order.folioReference}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.folioReference,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  CamporeeOrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      camporeeOrderDistributionLabel(order.distributionStatus),
                      style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary),
                    ),
                  ),
                  Text(
                    SacMoney.fromCentavos(order.totalCentavos),
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;

  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w600,
          color: context.sac.text,
        ),
      ),
    );
  }
}

String camporeeOrderStatusLabel(CamporeeOrderStatus status) {
  switch (status) {
    case CamporeeOrderStatus.issued:
      return 'camporee_orders.status.issued'.tr();
    case CamporeeOrderStatus.proofSubmitted:
      return 'camporee_orders.status.proof_submitted'.tr();
    case CamporeeOrderStatus.proofRejected:
      return 'camporee_orders.status.proof_rejected'.tr();
    case CamporeeOrderStatus.paid:
      return 'camporee_orders.status.paid'.tr();
    case CamporeeOrderStatus.delivered:
      return 'camporee_orders.status.delivered'.tr();
    case CamporeeOrderStatus.cancelled:
      return 'camporee_orders.status.cancelled'.tr();
    case CamporeeOrderStatus.expired:
      return 'camporee_orders.status.expired'.tr();
  }
}

String camporeeOrderDistributionLabel(CamporeeOrderDistributionStatus status) {
  switch (status) {
    case CamporeeOrderDistributionStatus.notStarted:
      return 'camporee_orders.distribution.not_started'.tr();
    case CamporeeOrderDistributionStatus.partial:
      return 'camporee_orders.distribution.partial'.tr();
    case CamporeeOrderDistributionStatus.complete:
      return 'camporee_orders.distribution.complete'.tr();
  }
}

/// Insignia del estado de un folio. Cada estado lleva su propio icono para
/// que pagado y entregado no se distingan solo por el color.
class CamporeeOrderStatusBadge extends StatelessWidget {
  final CamporeeOrderStatus status;

  const CamporeeOrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = camporeeOrderStatusLabel(status);
    switch (status) {
      case CamporeeOrderStatus.issued:
        return SacBadge.warning(
          label: label,
          icon: HugeIcons.strokeRoundedClock01,
        );
      case CamporeeOrderStatus.proofSubmitted:
        return SacBadge(
          label: label,
          icon: HugeIcons.strokeRoundedUpload01,
        );
      case CamporeeOrderStatus.paid:
        return SacBadge.success(
          label: label,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case CamporeeOrderStatus.delivered:
        return SacBadge.success(
          label: label,
          icon: HugeIcons.strokeRoundedPackageDelivered,
        );
      case CamporeeOrderStatus.proofRejected:
        return SacBadge.error(
          label: label,
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case CamporeeOrderStatus.expired:
        return SacBadge.error(
          label: label,
          icon: HugeIcons.strokeRoundedTimeQuarterPass,
        );
      case CamporeeOrderStatus.cancelled:
        return SacBadge(
          label: label,
          variant: SacBadgeVariant.neutral,
          icon: HugeIcons.strokeRoundedCancel01,
        );
    }
  }
}

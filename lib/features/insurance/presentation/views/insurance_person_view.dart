import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/back_or_home.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../payment_orders/domain/entities/payment_order.dart';
import '../../../payment_orders/presentation/providers/payment_orders_providers.dart';
import '../../domain/entities/insurance_overview.dart';
import '../providers/insurance_providers.dart';
import '../utils/insurance_formatting.dart';
import '../widgets/insurance_message_state.dart';
import '../widgets/insurance_skeleton.dart';
import '../widgets/insurance_ui.dart';

/// Seguro de la persona: el año, dónde se pagó, o de quién vino. Sin póliza,
/// aseguradora ni monto.
class InsurancePersonView extends ConsumerWidget {
  const InsurancePersonView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final overviewAsync = ref.watch(insuranceOverviewProvider);
    final access =
        ref.watch(insuranceAccessProvider).value ?? InsuranceAccess.readOnly;
    final overview = overviewAsync.value;
    final person = overview?.personById(userId);

    Widget body;
    // Riverpod 3 keeps the previous value while reloading: right after a
    // reassignment that stale value still has the person uninsured. This
    // screen has no pull-to-refresh, so wait for the fresh data instead.
    if (overviewAsync.isLoading) {
      body = const InsuranceSkeleton(rows: 3);
    } else if (overview == null && overviewAsync.hasError) {
      body = InsuranceMessageState.loadError(
        error: overviewAsync.error,
        onRetry: () => ref.invalidate(insuranceOverviewProvider),
      );
    } else if (person == null || overview == null) {
      body = InsuranceMessageState(
        title: tr('insurance.person.not_found_title'),
        body: tr('insurance.person.not_found_body'),
        icon: HugeIcons.strokeRoundedUser,
      );
    } else {
      body = _Body(
        person: person,
        year: overview.year,
        canViewOrders: access.canViewOrders,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: person?.name ?? '',
        backgroundColor: c.canvas,
        frosted: true,
        onBack: () => backOrHome(context),
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.person,
    required this.year,
    required this.canViewOrders,
  });

  final InsurancePerson person;
  final InsuranceYear? year;
  final bool canViewOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = person.coverage;
    final yearLabel = year?.label ?? '';
    final source = coverage?.source ?? CoverageSource.paidHere;

    // The overview only carries the folio: look the order up to open it.
    final orders = canViewOrders && source != CoverageSource.paidElsewhere
        ? ref
            .watch(
              paymentOrdersListProvider(
                const PaymentOrdersFilter(
                    purpose: PaymentOrderPurpose.insurance),
              ),
            )
            .value
        : null;
    String? orderId;
    if (orders != null && coverage?.orderFolio != null) {
      for (final o in orders) {
        if (o.folioReference == coverage!.orderFolio) orderId = o.orderId;
      }
    }
    VoidCallback? openOrder = orderId == null
        ? null
        : () => context.push(RouteNames.paymentOrderDetailPath(orderId!));

    final place = insurancePlace(
      coverage?.paidInSectionName,
      coverage?.paidInClubName,
    );
    final style = SacStatusStyle.of(
      context,
      SacStatusKind.validated,
      label: tr('insurance.status.covered'),
      icon: HugeIcons.strokeRoundedShieldUser,
    );

    final String title;
    final String message;
    final List<Widget> rows;
    final folio = coverage?.orderFolio;
    final approved = coverage?.approvedAt;
    switch (source) {
      case CoverageSource.paidElsewhere:
        title = tr('insurance.person.title_elsewhere');
        message = tr(
          'insurance.person.message_elsewhere',
          namedArgs: {'year': yearLabel, 'place': place ?? '-'},
        );
        rows = [
          InsuranceKvRow(label: tr('insurance.person.year'), value: yearLabel),
          InsuranceKvRow(
            label: tr('insurance.person.paid_in'),
            value: place ?? '-',
          ),
          if (folio != null)
            InsuranceKvRow(label: tr('insurance.person.order'), value: folio),
          if (approved != null)
            InsuranceKvRow(
              label: tr('insurance.person.approved'),
              value: insuranceFullDate(context, approved),
            ),
        ];
      case CoverageSource.reassigned:
        final by = coverage?.reassignedByName;
        final at = coverage?.reassignedAt;
        title = tr('insurance.person.title_covered',
            namedArgs: {'year': yearLabel});
        message = coverage?.reassignedFromName == null
            ? tr('insurance.person.message_reassigned_generic')
            : tr(
                'insurance.person.message_reassigned',
                namedArgs: {'name': coverage!.reassignedFromName!},
              );
        rows = [
          InsuranceKvRow(label: tr('insurance.person.year'), value: yearLabel),
          if (coverage?.reassignedFromName != null)
            InsuranceKvRow(
              label: tr('insurance.person.reassigned_from'),
              value: coverage!.reassignedFromName!,
            ),
          if (by != null)
            InsuranceKvRow(
              label: tr('insurance.person.reassigned_by'),
              value:
                  at == null ? by : '$by · ${insuranceShortDate(context, at)}',
            ),
          if (folio != null)
            InsuranceKvRow(
              label: tr('insurance.person.original_order'),
              value: folio,
              onTap: openOrder,
            ),
        ];
      case CoverageSource.paidHere:
        title = tr('insurance.person.title_covered',
            namedArgs: {'year': yearLabel});
        message = tr(
          'insurance.person.message_covered',
          namedArgs: {'next': _nextYear(yearLabel)},
        );
        rows = [
          InsuranceKvRow(label: tr('insurance.person.year'), value: yearLabel),
          if (place != null)
            InsuranceKvRow(label: tr('insurance.person.paid_in'), value: place),
          if (folio != null)
            InsuranceKvRow(
              label: tr('insurance.person.order'),
              value: folio,
              onTap: openOrder,
            ),
          if (approved != null)
            InsuranceKvRow(
              label: tr('insurance.person.approved'),
              value: insuranceFullDate(context, approved),
            ),
        ];
    }

    return ListView(
      padding: SacTopBar.paddingBelowBar(
        context,
        const EdgeInsets.only(top: 4, bottom: 32),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Material(
            color: style.container,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: style.icon,
                        size: 20,
                        color: style.onContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: SacFontSize.titleLarge,
                            fontWeight: FontWeight.w700,
                            color: style.onContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      height: 1.4,
                      color: style.onContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SacGroupedSection(
          key: const ValueKey('insurance-person-details'),
          label: tr('insurance.person.insurance'),
          // Key-value details, not a list: no count in the eyebrow.
          action: const SizedBox.shrink(),
          dividerIndent: 14,
          children: rows,
        ),
      ],
    );
  }

  String _nextYear(String label) {
    final n = int.tryParse(label);
    return n == null ? label : '${n + 1}';
  }
}

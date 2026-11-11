import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/widgets/secure_screen.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../domain/entities/finance_month.dart';
import '../../domain/entities/finance_summary.dart';
import '../providers/finances_providers.dart';
import '../widgets/balance_header_card.dart';
import '../widgets/finance_menu_sheet.dart';
import '../widgets/finance_month_transition.dart';
import '../widgets/finances_content.dart';
import '../widgets/finances_loading_skeleton.dart';
import 'add_transaction_sheet.dart';

/// Pantalla principal del módulo de Finanzas.
///
/// Muestra el saldo acumulado, el resumen del mes seleccionado,
/// un gráfico de líneas con selector de período y la lista agrupada
/// de transacciones por fecha.
///
/// Al cambiar de mes el encabezado (saldo, mes y flechas) nunca desaparece: el
/// contenido del mes anterior se atenúa mientras carga y el del mes nuevo entra
/// deslizándose hacia el lado en que se viaja. Solo la primera carga muestra el
/// esqueleto completo.
class FinancesView extends ConsumerStatefulWidget {
  const FinancesView({super.key});

  @override
  ConsumerState<FinancesView> createState() => _FinancesViewState();
}

class _FinancesViewState extends ConsumerState<FinancesView> {
  /// Mes cuyos datos muestra el contenido (el último que terminó de cargar).
  SelectedMonth? _shownMonth;

  /// Sentido del último viaje entre meses: 1 hacia uno posterior, -1 anterior.
  int _direction = 1;

  void _refresh() => invalidateFinanceData(ref.invalidate);

  @override
  Widget build(BuildContext context) {
    // Precarga el mes anterior en cuanto el seleccionado terminó de cargar.
    ref.watch(financePrefetchProvider);

    final selected = ref.watch(selectedMonthProvider);
    final month = ref.watch(financeMonthProvider);
    final summary = ref.watch(financeSummaryProvider);
    final byCategory = ref.watch(financeByCategoryProvider);
    final canManage = ref.watch(canManageFinancesProvider).value ?? false;
    // `period_closed` of the summary (falls back to the month's movements).
    final isClosed = ref.watch(financePeriodClosedProvider);
    final isActing = ref.watch(actingDependentProvider) != null;

    final isLoading =
        month.isLoading || summary.isLoading || byCategory.isLoading;
    final isStale = isLoading || month.hasError;

    if (!isStale && _shownMonth != selected) {
      final shown = _shownMonth;
      if (shown != null) _direction = selected.compareTo(shown) >= 0 ? 1 : -1;
      _shownMonth = selected;
    }

    return SecureScreen(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
          title: 'finances.view.title'.tr(),
          frosted: true,
          actions: [
            if (canManage && !isClosed)
              _TopBarAction(
                tooltip: 'finances.add_transaction.new_title'.tr(),
                onPressed: () => _openAddSheet(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  size: 22,
                  color: SacAccent.of(context).color,
                ),
              ),
            if (!selected.isCurrentMonth)
              _TopBarAction(
                tooltip: 'finances.view.go_current_month'.tr(),
                onPressed: () =>
                    ref.read(selectedMonthProvider.notifier).goToCurrent(),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 20,
                  color: context.sac.textSecondary,
                ),
              ),
            _TopBarAction(
              tooltip: 'common.refresh'.tr(),
              onPressed: isLoading ? null : _refresh,
              icon: isLoading
                  ? const SacLoadingSmall()
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      size: 20,
                      color: context.sac.textSecondary,
                    ),
            ),
            // Exportar y el informe son del club propio: no se ofrecen
            // mientras se actúa por un menor.
            if (!isActing)
              _TopBarAction(
                tooltip: 'finances.view.more_options'.tr(),
                onPressed: () => showFinanceMenuSheet(
                  context,
                  onOpenReport: (enrollmentId) => context.push(
                    RouteNames.monthlyReportsPath(enrollmentId),
                  ),
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreVertical,
                  size: 20,
                  color: context.sac.textSecondary,
                ),
              ),
          ],
        ),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) => SafeArea(
              top: false,
              child: RefreshIndicator(
                color: SacAccent.of(context).color,
                edgeOffset: SacTopBar.frostedInset(context),
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: SacTopBar.frostedInset(context)),
                    ),
                    SliverToBoxAdapter(
                      child: _buildBody(
                        selected: selected,
                        month: month,
                        summary: summary,
                        isStale: isStale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required SelectedMonth selected,
    required FinanceSlice<FinanceMonth> month,
    required FinanceSlice<FinanceSummary> summary,
    required bool isStale,
  }) {
    // Primera carga: todavía no hay nada que mostrar.
    if (month.value == null && month.isLoading && !month.hasError) {
      return const FinancesLoadingSkeleton();
    }

    final error = month.error;
    // Primer intento fallido: sin encabezado que conservar.
    if (error != null && month.value == null) {
      return SacErrorState(
        title: 'finances.view.error_title'.tr(),
        message: userErrorMessage(error),
        onRetry: _refresh,
      );
    }

    final financeMonth = month.value;
    // Si el resumen del mes falló, `summary.value` es el del mes anterior.
    final monthSummary = summary.hasError ? null : summary.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saldo acumulado (toda la historia) y totales SOLO del mes, del
        // resumen. Siempre montado: cambiar de mes nunca lo reemplaza.
        BalanceHeaderCard(
          financeMonth: financeMonth,
          totalBalance:
              monthSummary?.totalBalance ?? financeMonth?.totalBalance ?? 0.0,
          periodIncome: monthSummary?.totalIncome,
          periodExpense: monthSummary?.totalExpense,
          isStale: isStale,
        ),
        if (error != null)
          SacErrorState(
            title: 'finances.view.error_title'.tr(),
            message: userErrorMessage(error),
            onRetry: _refresh,
          )
        else
          FinanceMonthTransition(
            monthKey: _shownMonth ?? selected,
            direction: _direction,
            isStale: isStale,
            child: FinancesContent(financeMonth: financeMonth),
          ),
      ],
    );
  }

  void _openAddSheet(BuildContext context) {
    showSacSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
  }
}

/// Botón de la barra superior con el feedback de pulsación de la app.
class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      listenOnly: true,
      child: IconButton(
        enableFeedback: false,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}

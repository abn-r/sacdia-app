import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

import '../../domain/entities/annual_continuation.dart';
import '../providers/members_providers.dart';
import '../widgets/continuation_row.dart';
import '../widgets/join_request_group.dart';
import '../widgets/members_list_skeleton.dart';

/// Lista de no inscritos del año vigente para la sección activa.
///
/// Acceso: `club_members:approve`.
/// GET/POST `/club-sections/{sectionId}/annual-continuations`
///
/// Scaffold propio para tests y rutas sueltas. En Miembros se embebe
/// [AnnualContinuationsBody] como tab.
class AnnualContinuationsView extends ConsumerWidget {
  const AnnualContinuationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(annualContinuationsNotifierProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: tr('members.continuations.title'),
          onBack: () => Navigator.of(context).maybePop(),
          actions: [
            if (asyncState.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: SacLoadingSmall(color: c.textTertiary),
                ),
              )
            else
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  enableFeedback: false,
                  tooltip: 'common.refresh'.tr(),
                  onPressed: () =>
                      ref.invalidate(annualContinuationsNotifierProvider),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: c.textTertiary,
                    size: 18,
                  ),
                ),
              ),
          ],
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          // La barra inferior de la lista ya respeta el inset de abajo.
          builder: (context) => const SafeArea(
            top: false,
            bottom: false,
            child: AnnualContinuationsBody(underTopBar: true),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo de continuaciones anuales, sin app bar. Tab de Miembros.
///
/// [underTopBar]: el cuerpo se dibuja detrás de un [SacTopBar] esmerilado
/// (la vista suelta). En el tab de Miembros va debajo del selector, así que
/// no necesita ese espacio extra.
class AnnualContinuationsBody extends ConsumerStatefulWidget {
  const AnnualContinuationsBody({super.key, this.underTopBar = false});

  final bool underTopBar;

  @override
  ConsumerState<AnnualContinuationsBody> createState() =>
      _AnnualContinuationsBodyState();
}

class _AnnualContinuationsBodyState
    extends ConsumerState<AnnualContinuationsBody> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(annualContinuationsNotifierProvider);
    final hPad = Responsive.horizontalPadding(context);

    return asyncState.when(
      loading: () => const MembersListSkeleton(),
      error: (error, _) => SacErrorState(
        title: tr('members.continuations.errors.fetch'),
        message: userErrorMessage(error),
        onRetry: () => ref.invalidate(annualContinuationsNotifierProvider),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return SacEmptyState(
            icon: HugeIcons.strokeRoundedUserCheck01,
            title: tr('members.continuations.empty_title'),
            body: tr('members.continuations.empty_subtitle'),
          );
        }
        return _buildContent(context, state, hPad);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AnnualContinuationsState state,
    double hPad,
  ) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final notifier = ref.read(annualContinuationsNotifierProvider.notifier);
    final classes = _classesById(ref.watch(allClassesProvider).value);

    final ready = state.enrollableItems;
    final blocked = state.items.where((m) => m.isBlocked).toList();
    final selectedCount =
        ready.where((m) => state.selectedIds.contains(m.userId)).length;
    final allSelected = ready.isNotEmpty && selectedCount == ready.length;
    final period = state.periodLabel;

    // Debajo del selector de Miembros no hay barra que esquivar; solo la vista
    // suelta dibuja detrás de su barra esmerilada.
    const base = EdgeInsets.only(top: 4, bottom: 24);
    final listPadding =
        (widget.underTopBar ? SacTopBar.paddingBelowBar(context, base) : base)
            .copyWith(left: hPad, right: hPad);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: listPadding,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                child: Text(
                  tr('members.continuations.subtitle'),
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              if (ready.isNotEmpty)
                JoinRequestGroupSection(
                  title: tr('members.continuations.group_ready'),
                  count: ready.length,
                  dotColor: accent.color,
                  trailing: SacButton.text(
                    text: allSelected
                        ? tr('members.continuations.clear_all')
                        : tr('members.continuations.select_all'),
                    onPressed:
                        allSelected ? notifier.clearAll : notifier.selectAll,
                  ),
                  children: [
                    for (final item in ready)
                      ContinuationSelectableRow(
                        key: ValueKey('continuation-${item.userId}'),
                        item: item,
                        isSelected: state.selectedIds.contains(item.userId),
                        classInfo: _classInfoFor(item, classes),
                        onToggle: () => notifier.toggleSelection(item.userId),
                      ),
                  ],
                ),
              if (ready.isNotEmpty && blocked.isNotEmpty)
                const SizedBox(height: 20),
              if (blocked.isNotEmpty)
                JoinRequestGroupSection(
                  title: tr('members.continuations.group_blocked'),
                  count: blocked.length,
                  dotColor: c.warning,
                  children: [
                    for (final item in blocked)
                      ContinuationBlockedRow(
                        key: ValueKey('continuation-${item.userId}'),
                        item: item,
                      ),
                  ],
                ),
            ],
          ),
        ),
        // Nobody can be enrolled (all blocked): no action to offer.
        if (ready.isNotEmpty)
          _ContinuationsBottomBar(
            selectedCount: selectedCount,
            totalCount: ready.length,
            period: period,
            isSubmitting: _isSubmitting,
            onSubmit: () => _submit(context),
          ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final ContinuationBatchResult? result;
    try {
      result =
          await ref.read(annualContinuationsNotifierProvider.notifier).submit();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    if (!context.mounted) return;

    if (result == null) {
      SacSnackBar.show(context, tr('members.continuations.errors.submit'),
          isError: true);
      return;
    }

    final enrolled = result.enrolledCount + result.alreadyEnrolledCount;
    final message = result.hasPartialFailure
        ? tr(
            'members.continuations.success_partial',
            namedArgs: {
              'enrolled': enrolled.toString(),
              'blocked': result.blockedCount.toString(),
              'failed': result.failedCount.toString(),
            },
          )
        : tr(
            'members.continuations.success',
            namedArgs: {'count': enrolled.toString()},
          );

    SacSnackBar.show(context, message, isSuccess: !result.hasPartialFailure);
  }
}

/// Catálogo de clases por id; vacío mientras carga o si falla (el subtítulo
/// entonces solo muestra el cargo).
Map<int, ProgressiveClass> _classesById(List<ProgressiveClass>? classes) {
  if (classes == null) return const {};
  return {for (final cls in classes) cls.id: cls};
}

final _assetCodePattern = RegExp(r'^(AV|CQ|GM)-\d{2}$');

ContinuationClassInfo? _classInfoFor(
  AnnualContinuation item,
  Map<int, ProgressiveClass> classes,
) {
  final classId = item.suggestedClass.classId;
  if (classId == null) return null;
  final cls = classes[classId];
  if (cls == null || cls.name.trim().isEmpty) return null;
  final code = cls.assetCode?.trim().toUpperCase();
  final logo = (code != null && _assetCodePattern.hasMatch(code))
      ? 'assets/img/logos-clases/$code.png'
      : AppColors.classLogoAsset(cls.name);
  return ContinuationClassInfo(name: cls.name, logoAsset: logo);
}

/// Barra fija: cuántos hay marcados y la acción de inscribir.
class _ContinuationsBottomBar extends StatelessWidget {
  const _ContinuationsBottomBar({
    required this.selectedCount,
    required this.totalCount,
    required this.period,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int selectedCount;
  final int totalCount;
  final String? period;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final helper = selectedCount == 0
        ? tr('members.continuations.select_at_least_one')
        : 'members.continuations.selected_count'.plural(
            selectedCount,
            namedArgs: {'total': totalCount.toString()},
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  helper,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    color: c.textSecondary,
                  ),
                ),
              ),
              SacButton.primary(
                text: period == null
                    ? tr('members.continuations.submit_button_no_period')
                    : tr(
                        'members.continuations.submit_button',
                        namedArgs: {'period': period!},
                      ),
                borderRadius: AppTheme.radiusFull,
                isLoading: isSubmitting,
                isEnabled: selectedCount > 0,
                onPressed: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../domain/entities/scoring_category.dart';
import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';
import '../providers/units_providers.dart';

/// Asignación semanal de puntos — UI minimalista.
///
/// Solo lo esencial: miembros + categorías + guardar.
/// Meta de unidad, progress bars y acciones secundarias viven
/// fuera del camino principal (toolbar / long-press / sheet).
class UnitDetailView extends ConsumerWidget {
  final Unit unit;

  const UnitDetailView({super.key, required this.unit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unitsNotifierProvider);
    final notifier = ref.read(unitsNotifierProvider.notifier);
    final c = context.sac;

    final canRegisterPoints = _canRegisterPoints(ref, unit);
    final members = state.members;
    final showBulk = canRegisterPoints &&
        state.categories.isNotEmpty &&
        !state.isSavedToday;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: unit.name,
        centerTitle: true,
        onBack: () => Navigator.of(context).pop(),
        actions: [
          if (showBulk)
            TextButton(
              onPressed: () => _openBulkSheet(
                context,
                categories: state.categories,
                onSetForAll: (category, value) {
                  HapticFeedback.selectionClick();
                  notifier.setCategoryPointsForAllMembers(
                    category.scoringCategoryId,
                    value,
                  );
                },
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserMultiple,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'units.detail.bulk_action_button'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.isSavedToday) const _SavedStatusStrip(),
          Expanded(
            child: members.isEmpty
                ? const SizedBox.shrink()
                : _MemberScoreList(
                    members: members,
                    categories: state.categories,
                    pendingScores: state.pendingScores,
                    totalFor: state.totalPendingForMember,
                    isDisabled: state.isSavedToday || !canRegisterPoints,
                    isReadOnly: !canRegisterPoints,
                    topPadding: state.isSavedToday ? 8 : 12,
                    bottomPadding: canRegisterPoints ? 16 : 28,
                    onAdjust: (memberId, categoryId, delta) {
                      HapticFeedback.selectionClick();
                      notifier.adjustCategoryPoints(
                        memberId,
                        categoryId,
                        delta,
                      );
                    },
                    onSetValue: (memberId, categoryId, value) {
                      HapticFeedback.selectionClick();
                      notifier.setCategoryPoints(
                        memberId,
                        categoryId,
                        value,
                      );
                    },
                    onSetAll: (memberId) {
                      HapticFeedback.lightImpact();
                      notifier.setAllCategoryPointsForMember(memberId);
                    },
                    onClear: (memberId) {
                      HapticFeedback.lightImpact();
                      notifier.clearCategoryPointsForMember(memberId);
                    },
                  ),
          ),
          if (canRegisterPoints)
            _SaveFooter(
              isSavedToday: state.isSavedToday,
              isSaving: state.isSaving,
              onSave: () => _handleSave(context, notifier),
              onReset: () => notifier.resetSession(),
            ),
        ],
      ),
    );
  }

  bool _canRegisterPoints(WidgetRef ref, Unit unit) {
    return ref.watch(clubContextProvider).maybeWhen(
          data: (ctx) {
            if (ctx == null) return false;
            final role = ctx.roleName?.toLowerCase() ?? '';
            if ([
              'director',
              'sub_director',
              'secretario',
              'secretario_tesorero',
            ].contains(role)) {
              return true;
            }
            final userId = ref.read(authNotifierProvider).value?.id ?? '';
            if (userId.isEmpty) return false;
            return unit.advisorId == userId ||
                unit.substituteAdvisorId == userId ||
                unit.captainId == userId;
          },
          orElse: () => false,
        );
  }

  void _handleSave(BuildContext context, UnitsNotifier notifier) {
    notifier.saveSession().then((saved) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'units.detail.save_success'.tr()
                : 'units.detail.save_error'.tr(),
          ),
          backgroundColor: saved ? AppColors.secondary : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (saved) HapticFeedback.mediumImpact();
    });
  }

  Future<void> _openBulkSheet(
    BuildContext context, {
    required List<ScoringCategory> categories,
    required void Function(ScoringCategory, int) onSetForAll,
  }) {
    final c = context.sac;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'units.detail.bulk_categories_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 12),
                ...categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        _SheetChip(
                          label: 'units.detail.min_button'.tr(),
                          onTap: () => onSetForAll(category, 0),
                        ),
                        const SizedBox(width: 8),
                        _SheetChip(
                          label: 'units.detail.max_button'.tr(),
                          emphasized: true,
                          onTap: () =>
                              onSetForAll(category, category.maxPoints),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SacButton.primary(
                  text: 'units.detail.bulk_done_button'.tr(),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Status ────────────────────────────────────────────────────────────────────

class _SavedStatusStrip extends StatelessWidget {
  const _SavedStatusStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.secondaryLight.withValues(alpha: 0.55),
      child: Text(
        'units.detail.saved_today_banner'.tr(),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Member list (expand state owned here, keyed by member.id) ─────────────────

class _MemberScoreList extends StatefulWidget {
  final List<UnitMember> members;
  final List<ScoringCategory> categories;
  final Map<String, Map<int, int>> pendingScores;
  final int Function(String memberId) totalFor;
  final bool isDisabled;
  final bool isReadOnly;
  final double topPadding;
  final double bottomPadding;
  final void Function(String memberId, int categoryId, int delta) onAdjust;
  final void Function(String memberId, int categoryId, int value) onSetValue;
  final void Function(String memberId) onSetAll;
  final void Function(String memberId) onClear;

  const _MemberScoreList({
    required this.members,
    required this.categories,
    required this.pendingScores,
    required this.totalFor,
    required this.isDisabled,
    required this.isReadOnly,
    required this.topPadding,
    required this.bottomPadding,
    required this.onAdjust,
    required this.onSetValue,
    required this.onSetAll,
    required this.onClear,
  });

  @override
  State<_MemberScoreList> createState() => _MemberScoreListState();
}

class _MemberScoreListState extends State<_MemberScoreList> {
  /// Expand/collapse by member id — survives ListView rebuilds & recycling.
  final Map<String, bool> _expandedById = {};

  bool _isExpanded(String memberId) => _expandedById[memberId] ?? true;

  void _toggle(String memberId) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedById[memberId] = !_isExpanded(memberId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, widget.topPadding, 16, widget.bottomPadding),
      itemCount: widget.members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = widget.members[index];
        return _MemberCard(
          key: ValueKey(member.id),
          member: member,
          categories: widget.categories,
          scores: widget.pendingScores[member.id] ?? const {},
          total: widget.totalFor(member.id),
          expanded: _isExpanded(member.id),
          isDisabled: widget.isDisabled,
          isReadOnly: widget.isReadOnly,
          onToggle: () => _toggle(member.id),
          onAdjust: (categoryId, delta) =>
              widget.onAdjust(member.id, categoryId, delta),
          onSetValue: (categoryId, value) =>
              widget.onSetValue(member.id, categoryId, value),
          onSetAll: () => widget.onSetAll(member.id),
          onClear: () => widget.onClear(member.id),
        );
      },
    );
  }
}

// ── Member cards (tap = expand/collapse, long-press = actions) ────────────────

class _MemberCard extends StatelessWidget {
  final UnitMember member;
  final List<ScoringCategory> categories;
  final Map<int, int> scores;
  final int total;
  final bool expanded;
  final bool isDisabled;
  final bool isReadOnly;
  final VoidCallback onToggle;
  final void Function(int categoryId, int delta) onAdjust;
  final void Function(int categoryId, int value) onSetValue;
  final VoidCallback onSetAll;
  final VoidCallback onClear;

  const _MemberCard({
    super.key,
    required this.member,
    required this.categories,
    required this.scores,
    required this.total,
    required this.expanded,
    required this.isDisabled,
    required this.isReadOnly,
    required this.onToggle,
    required this.onAdjust,
    required this.onSetValue,
    required this.onSetAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasPoints = total > 0;
    final reduce = SacMotion.reduceMotionOf(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: categories.isEmpty ? null : onToggle,
            onLongPress: isReadOnly || isDisabled
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    _showMemberActions(context);
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  _MemberAvatar(member: member),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                    ),
                  ),
                  Text(
                    '$total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: hasPoints ? AppColors.primary : c.textTertiary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce ? Duration.zero : SacMotion.press,
                      curve: SacMotion.easeOut,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: reduce ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            alignment: Alignment.topCenter,
            child: !expanded || categories.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 10, 10),
                    child: Column(
                      children: categories.map((category) {
                        final points =
                            scores[category.scoringCategoryId] ?? 0;
                        return _CategoryRow(
                          category: category,
                          points: points,
                          isDisabled: isDisabled,
                          isReadOnly: isReadOnly,
                          onAdjust: (delta) =>
                              onAdjust(category.scoringCategoryId, delta),
                          onSetValue: (v) =>
                              onSetValue(category.scoringCategoryId, v),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberActions(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.sac.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 22,
                  color: AppColors.primary,
                ),
                title: Text('units.detail.assign_all_button'.tr()),
                onTap: () => Navigator.of(sheetContext).pop('all'),
              ),
              ListTile(
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedEraser01,
                  size: 22,
                  color: context.sac.textSecondary,
                ),
                title: Text('units.detail.clear_button'.tr()),
                onTap: () => Navigator.of(sheetContext).pop('clear'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result == 'all') onSetAll();
    if (result == 'clear') onClear();
  }
}

class _CategoryRow extends StatelessWidget {
  final ScoringCategory category;
  final int points;
  final bool isDisabled;
  final bool isReadOnly;
  final void Function(int delta) onAdjust;
  final void Function(int value) onSetValue;

  const _CategoryRow({
    required this.category,
    required this.points,
    required this.isDisabled,
    required this.isReadOnly,
    required this.onAdjust,
    required this.onSetValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final canEdit = !isReadOnly && !isDisabled;
    final value = category.normalizePoints(points);

    if (category.isBooleanFull) {
      return SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
            ),
            Switch.adaptive(
              value: value == category.maxPoints,
              onChanged: canEdit
                  ? (checked) => onSetValue(checked ? category.maxPoints : 0)
                  : null,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
          if (isReadOnly)
            Text(
              '$value',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: value > 0 ? c.text : c.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            )
          else
            _Stepper(
              value: value,
              max: category.maxPoints,
              enabled: canEdit,
              onDecrement: () => onAdjust(-1),
              onIncrement: () => onAdjust(1),
              onTapValue: canEdit ? () => _openManualDialog(context) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _openManualDialog(BuildContext context) async {
    final controller = TextEditingController(text: '$points');
    final formKey = GlobalKey<FormState>();
    final material = MaterialLocalizations.of(context);

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(category.name),
          content: Form(
            key: formKey,
            child: SacTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                if (parsed == null ||
                    parsed < 0 ||
                    parsed > category.maxPoints) {
                  return '0 – ${category.maxPoints}';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(material.cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(dialogContext)
                    .pop(int.parse(controller.text.trim()));
              },
              child: Text(material.okButtonLabel),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result != null) onSetValue(result);
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int max;
  final bool enabled;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onTapValue;

  const _Stepper({
    required this.value,
    required this.max,
    required this.enabled,
    required this.onDecrement,
    required this.onIncrement,
    this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: HugeIcons.strokeRoundedMinusSign,
          enabled: enabled && value > 0,
          onTap: onDecrement,
        ),
        _TapScale(
          onTap: onTapValue,
          child: SizedBox(
            width: 40,
            height: 44,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: !enabled
                          ? c.textTertiary
                          : value > 0
                              ? c.text
                              : c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ),
        ),
        _StepButton(
          icon: HugeIcons.strokeRoundedAdd01,
          enabled: enabled && value < max,
          filled: true,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final dynamic icon;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final bg = !enabled
        ? c.surfaceVariant.withValues(alpha: 0.4)
        : filled
            ? AppColors.primaryLight
            : c.surfaceVariant;
    final fg = !enabled
        ? c.textTertiary
        : filled
            ? AppColors.primaryDark
            : c.textSecondary;

    return _TapScale(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: SacMotion.press,
            curve: SacMotion.easeOut,
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: HugeIcon(icon: icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final UnitMember member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: member.avatar != null
            ? CachedNetworkImage(
                imageUrl: member.avatar!,
                fit: BoxFit.cover,
                memCacheWidth: 72,
                memCacheHeight: 72,
                placeholder: (_, __) => _initials(theme),
                errorWidget: (_, __, ___) => _initials(theme),
              )
            : _initials(theme),
      ),
    );
  }

  Widget _initials(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        member.initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool emphasized;
  final VoidCallback onTap;

  const _SheetChip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _TapScale(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: emphasized ? AppColors.primaryLight : c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: emphasized ? AppColors.primaryDark : c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _SaveFooter extends StatelessWidget {
  final bool isSavedToday;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _SaveFooter({
    required this.isSavedToday,
    required this.isSaving,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final solid = MediaQuery.maybeOf(context)?.highContrast == true;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: solid ? 0 : 18,
          sigmaY: solid ? 0 : 18,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: solid ? 1 : 0.78),
            border: Border(
              top: BorderSide(color: c.border.withValues(alpha: 0.5)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: isSavedToday
                ? SacButton.outline(
                    text: 'units.detail.reset_button'.tr(),
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: onReset,
                  )
                : SacButton.primary(
                    text: 'units.detail.save_button'.tr(),
                    icon: HugeIcons.strokeRoundedFloppyDisk,
                    isLoading: isSaving,
                    onPressed: onSave,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TapScale({required this.child, this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v || widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.96 : 1,
        duration: SacMotion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

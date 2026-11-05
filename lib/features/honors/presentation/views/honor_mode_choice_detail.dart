import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_abandon_menu_button.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_action_bar.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_band_scaffold.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_catalog_info_tab.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_progress_band.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_work_mode_selector.dart';

/// Screen of an enrolled honor whose work mode is not chosen yet.
///
/// The band reaches only the first step and has no ring. "Cómo trabajarla"
/// offers the two modes (or a locked notice when the honor can no longer
/// change); "Información" is the same as the catalog's. The sticky bar waits
/// for a choice and then names it: [onSelectCompletionMode] confirms and
/// saves it.
class HonorModeChoiceDetail extends StatefulWidget {
  const HonorModeChoiceDetail({
    super.key,
    required this.honor,
    required this.userHonor,
    required this.categoryName,
    required this.isLoading,
    required this.onSelectCompletionMode,
  });

  final Honor honor;
  final UserHonor userHonor;
  final String? categoryName;
  final bool isLoading;
  final ValueChanged<HonorCompletionMode> onSelectCompletionMode;

  @override
  State<HonorModeChoiceDetail> createState() => _HonorModeChoiceDetailState();
}

class _HonorModeChoiceDetailState extends State<HonorModeChoiceDetail> {
  HonorCompletionMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final honor = widget.honor;
    final userHonor = widget.userHonor;
    final paintColor = getCategoryPaintColor(
      categoryId: honor.categoryId,
      categoryName: widget.categoryName,
    );
    final bandColor = bandColorFor(
      categoryId: honor.categoryId,
      categoryName: widget.categoryName,
    );
    final onTint = honorOnTint(context, bandColor);
    final canChoose = userHonor.canSubmit;

    return HonorBandScaffold(
      bandColor: bandColor,
      paintColor: paintColor,
      honorName: honor.name,
      categoryName: widget.categoryName,
      imageUrl: honor.imageUrl ?? userHonor.honorImageUrl,
      step: userHonor.isUnderReview
          ? HonorWorkStep.inReview
          : HonorWorkStep.enrolled,
      metaLabel: 'honors.work_mode.band_meta'.tr(namedArgs: {
        'date': SacDateFormatter.formatCalendar(userHonor.date, 'd MMM yyyy'),
      }),
      actions: [
        // Abandoning here keeps the user on the detail, which falls back to
        // the catalog view once the enrollment disappears.
        HonorAbandonMenuButton(
          userHonor: userHonor,
          honorName: honor.name,
          popOnSuccess: false,
        ),
      ],
      tabLabels: [
        'honors.work_mode.tab_how'.tr(),
        'honors.requirements.tab_info'.tr(),
      ],
      tabBuilder: (context, tab) {
        if (tab == 1) {
          return HonorCatalogInfoTab(
            honor: honor,
            paintColor: paintColor,
            chipForeground: onTint,
          );
        }
        if (!canChoose) {
          return _LockedWorkModeCard(userHonor: userHonor, accent: onTint);
        }
        return _ChooseModeTab(
          bandColor: bandColor,
          isLoading: widget.isLoading,
          selectedMode: _selectedMode,
          onSelected: (mode) => setState(() => _selectedMode = mode),
        );
      },
      bottomBar: canChoose
          ? _ContinueBar(
              bandColor: bandColor,
              selectedMode: _selectedMode,
              isLoading: widget.isLoading,
              onContinue: () {
                final mode = _selectedMode;
                if (mode == null) return;
                widget.onSelectCompletionMode(mode);
              },
            )
          : null,
    );
  }
}

class _ChooseModeTab extends StatelessWidget {
  const _ChooseModeTab({
    required this.bandColor,
    required this.isLoading,
    required this.selectedMode,
    required this.onSelected,
  });

  final Color bandColor;
  final bool isLoading;
  final HonorCompletionMode? selectedMode;
  final ValueChanged<HonorCompletionMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'honors.work_mode.choose_title'.tr(),
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: c.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'honors.work_mode.subtitle'.tr(),
          style: text.bodyMedium?.copyWith(
            color: c.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        HonorWorkModeSelector(
          categoryColor: bandColor,
          isLoading: isLoading,
          selectedMode: selectedMode,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.bandColor,
    required this.selectedMode,
    required this.isLoading,
    required this.onContinue,
  });

  final Color bandColor;
  final HonorCompletionMode? selectedMode;
  final bool isLoading;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasSelection = selectedMode != null;
    final enabled = hasSelection && !isLoading;
    final label = switch (selectedMode) {
      HonorCompletionMode.inApp => 'honors.work_mode.continue_in_app'.tr(),
      HonorCompletionMode.external => 'honors.work_mode.continue_external'.tr(),
      _ => 'honors.detail.select_mode_cta'.tr(),
    };

    return HonorActionBar(
      child: SacButton.primary(
        key: const ValueKey('honor-mode-continue-button'),
        text: label,
        isLoading: isLoading,
        backgroundColor: enabled ? bandColor : c.surfaceVariant,
        textColor: enabled ? Colors.white : c.textTertiary,
        onPressed: enabled ? onContinue : null,
      ),
    );
  }
}

/// Notice that replaces the choice when the honor is under review or already
/// finished and the mode can no longer be picked.
class _LockedWorkModeCard extends StatelessWidget {
  const _LockedWorkModeCard({required this.userHonor, required this.accent});

  final UserHonor userHonor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final messageKey = userHonor.isUnderReview
        ? 'honors.detail.work_mode_locked_under_review'
        : userHonor.isCompleted
            ? 'honors.detail.work_mode_locked_completed'
            : 'honors.detail.work_mode_locked_default';

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLock,
                    size: 22,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'honors.detail.work_mode_locked_title'.tr(),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            messageKey.tr(),
            style: text.bodyMedium?.copyWith(
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

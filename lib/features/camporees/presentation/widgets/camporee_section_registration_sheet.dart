import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';

class CamporeeSectionRegistrationSheet extends ConsumerStatefulWidget {
  final Camporee camporee;
  final CamporeeSectionRegistration registration;
  final Future<bool> Function()? onConfirm;

  const CamporeeSectionRegistrationSheet({
    super.key,
    required this.camporee,
    required this.registration,
    this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Camporee camporee,
    required CamporeeSectionRegistration registration,
  }) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.sac.surface,
      barrierColor: context.sac.barrierColor,
      sheetAnimationStyle: disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 200),
              reverseDuration: Duration(milliseconds: 180),
            ),
      builder: (_) => CamporeeSectionRegistrationSheet(
        camporee: camporee,
        registration: registration,
      ),
    );
  }

  @override
  ConsumerState<CamporeeSectionRegistrationSheet> createState() =>
      _CamporeeSectionRegistrationSheetState();
}

class _CamporeeSectionRegistrationSheetState
    extends ConsumerState<CamporeeSectionRegistrationSheet> {
  bool _isSubmitting = false;
  bool _hasFailure = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _hasFailure = false;
    });

    final success = await (widget.onConfirm?.call() ??
        ref
            .read(registerCamporeeSectionProvider(widget.camporee.camporeeId)
                .notifier)
            .register());

    if (!mounted) return;
    if (!success) {
      setState(() {
        _isSubmitting = false;
        _hasFailure = true;
      });
      return;
    }

    final message = 'camporees.section_registration.success'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(liveRegion: true, child: Text(message)),
      ),
    );
    Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sac;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateFormat = DateFormat.yMMMd(context.locale.toString());
    final currency = NumberFormat.simpleCurrency(
      locale: context.locale.toString(),
    );
    final cost = widget.camporee.registrationCost;
    final costLabel = cost == null || cost == 0
        ? 'camporees.common.free'.tr()
        : currency.format(cost);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'camporees.section_registration.sheet_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'camporees.section_registration.sheet_description'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            _ConfirmationFacts(
              clubName: widget.registration.clubName,
              sectionName: widget.registration.sectionName,
              camporeeName: widget.camporee.name,
              cost: costLabel,
              startDate: dateFormat.format(widget.camporee.startDate.toLocal()),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.info.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserCheck01,
                    color: colors.info,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'camporees.section_registration.director_confirmation'
                          .tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasFailure) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  'camporees.section_registration.submit_error'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SacButton.primary(
              text: _hasFailure
                  ? 'camporees.section_registration.retry_submit'.tr()
                  : 'camporees.section_registration.confirm'.tr(),
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              isLoading: _isSubmitting,
              isEnabled: !_isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
            const SizedBox(height: 8),
            SacButton.ghost(
              text: 'common.cancel'.tr(),
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationFacts extends StatelessWidget {
  final String clubName;
  final String sectionName;
  final String camporeeName;
  final String cost;
  final String startDate;

  const _ConfirmationFacts({
    required this.clubName,
    required this.sectionName,
    required this.camporeeName,
    required this.cost,
    required this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('camporees.section_registration.club'.tr(), clubName),
      ('camporees.section_registration.section'.tr(), sectionName),
      ('camporees.section_registration.camporee'.tr(), camporeeName),
      ('camporees.section_registration.cost'.tr(), cost),
      ('camporees.section_registration.start_date'.tr(), startDate),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    rows[index].$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.sac.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[index].$2,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.sac.text,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../widgets/monthly_report_motion.dart';

class MonthlyReportManualDataFormView extends ConsumerStatefulWidget {
  final MonthlyReport report;

  const MonthlyReportManualDataFormView({super.key, required this.report});

  @override
  ConsumerState<MonthlyReportManualDataFormView> createState() =>
      _MonthlyReportManualDataFormViewState();
}

class _MonthlyReportManualDataFormViewState
    extends ConsumerState<MonthlyReportManualDataFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _planning;
  late final TextEditingController _parents;
  late final TextEditingController _youth;
  late final TextEditingController _church;
  late final TextEditingController _soulTarget;
  late final TextEditingController _unbaptized;
  late final TextEditingController _studies;
  late final TextEditingController _baptizedMonth;
  late final TextEditingController _baptizedTotal;
  late final TextEditingController _participation;
  late final TextEditingController _service;

  bool _weeklyInstruction = false;
  bool _studiesGiven = false;
  bool _literature = false;
  bool _certificates = false;
  bool _booklets = false;
  bool _bookletsSigned = false;

  @override
  void initState() {
    super.initState();
    final data = widget.report.manualData;
    _planning = _intController(data?.planningMeetings);
    _parents = _intController(data?.parentMeetings);
    _youth = _intController(data?.youthCouncilAttendance);
    _church = _intController(data?.churchBoardAttendance);
    _soulTarget = _intController(data?.soulTarget);
    _unbaptized = _intController(data?.unbaptizedMembers);
    _studies = _intController(data?.bibleStudiesReceiving);
    _baptizedMonth = _intController(data?.baptizedThisMonth);
    _baptizedTotal = _intController(data?.totalBaptized);
    _participation = TextEditingController(
      text: data?.clubParticipationDescription ?? '',
    );
    _service = TextEditingController(
      text: data?.communityServiceDescription ?? '',
    );
    _weeklyInstruction = data?.hasWeeklyBibleInstruction ?? false;
    _studiesGiven = data?.bibleStudiesGiven ?? false;
    _literature = data?.literatureDistributed ?? false;
    _certificates = data?.certificatesDelivered ?? false;
    _booklets = data?.membersHaveBooklet ?? false;
    _bookletsSigned = data?.bookletRequirementsSigned ?? false;
  }

  TextEditingController _intController(int? value) =>
      TextEditingController(text: value?.toString() ?? '');

  @override
  void dispose() {
    for (final controller in [
      _planning,
      _parents,
      _youth,
      _church,
      _soulTarget,
      _unbaptized,
      _studies,
      _baptizedMonth,
      _baptizedTotal,
      _participation,
      _service,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _intFrom(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? 0 : int.tryParse(text);
  }

  MonthlyReportManualData _buildData() => MonthlyReportManualData(
        planningMeetings: _intFrom(_planning),
        parentMeetings: _intFrom(_parents),
        youthCouncilAttendance: _intFrom(_youth),
        churchBoardAttendance: _intFrom(_church),
        soulTarget: _intFrom(_soulTarget),
        unbaptizedMembers: _intFrom(_unbaptized),
        bibleStudiesReceiving: _intFrom(_studies),
        hasWeeklyBibleInstruction: _weeklyInstruction,
        bibleStudiesGiven: _studiesGiven,
        literatureDistributed: _literature,
        baptizedThisMonth: _intFrom(_baptizedMonth),
        totalBaptized: _intFrom(_baptizedTotal),
        clubParticipationDescription: _participation.text.trim().isEmpty
            ? null
            : _participation.text.trim(),
        communityServiceDescription:
            _service.text.trim().isEmpty ? null : _service.text.trim(),
        certificatesDelivered: _certificates,
        membersHaveBooklet: _booklets,
        bookletRequirementsSigned: _bookletsSigned,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(monthlyReportMutationProvider.notifier)
        .saveManualData(widget.report.id, _buildData());
    if (!mounted) return;
    final state = ref.read(monthlyReportMutationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'monthly_reports.form.saved'.tr()
            : state.errorMessage ?? 'monthly_reports.form.save_error'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = ref.watch(monthlyReportMutationProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'monthly_reports.form.title'.tr(),
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
          children: [
            MonthlyReportEntrance(child: _FormIntroCard(report: widget.report)),
            const SizedBox(height: 18),
            MonthlyReportEntrance(
              index: 1,
              child: _FormSection(
                title: 'monthly_reports.form.meetings_title'.tr(),
                eyebrow: 'monthly_reports.form.meetings_eyebrow'.tr(),
                description: 'monthly_reports.form.meetings_description'.tr(),
                icon: HugeIcons.strokeRoundedCalendar01,
                children: [
                  _NumberField(
                    controller: _planning,
                    label: 'monthly_reports.form.planning_meetings'.tr(),
                  ),
                  _NumberField(
                    controller: _parents,
                    label: 'monthly_reports.form.parent_meetings'.tr(),
                  ),
                  _NumberField(
                    controller: _youth,
                    label: 'monthly_reports.form.youth_council_attendance'.tr(),
                  ),
                  _NumberField(
                    controller: _church,
                    label: 'monthly_reports.form.church_board_attendance'.tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MonthlyReportEntrance(
              index: 2,
              child: _FormSection(
                title: 'monthly_reports.form.mission_title'.tr(),
                eyebrow: 'monthly_reports.form.mission_eyebrow'.tr(),
                description: 'monthly_reports.form.mission_description'.tr(),
                icon: HugeIcons.strokeRoundedUserMultiple,
                children: [
                  _NumberField(
                    controller: _soulTarget,
                    label: 'monthly_reports.form.soul_target'.tr(),
                  ),
                  _NumberField(
                    controller: _unbaptized,
                    label: 'monthly_reports.form.unbaptized_members'.tr(),
                  ),
                  _NumberField(
                    controller: _studies,
                    label: 'monthly_reports.form.bible_studies_receiving'.tr(),
                  ),
                  _ReportSwitch(
                    title: 'monthly_reports.form.weekly_instruction'.tr(),
                    subtitle:
                        'monthly_reports.form.weekly_instruction_helper'.tr(),
                    value: _weeklyInstruction,
                    onChanged: (v) => setState(() => _weeklyInstruction = v),
                  ),
                  _ReportSwitch(
                    title: 'monthly_reports.form.studies_given'.tr(),
                    subtitle: 'monthly_reports.form.studies_given_helper'.tr(),
                    value: _studiesGiven,
                    onChanged: (v) => setState(() => _studiesGiven = v),
                  ),
                  _ReportSwitch(
                    title: 'monthly_reports.form.literature'.tr(),
                    subtitle: 'monthly_reports.form.literature_helper'.tr(),
                    value: _literature,
                    onChanged: (v) => setState(() => _literature = v),
                  ),
                  _NumberField(
                    controller: _baptizedMonth,
                    label: 'monthly_reports.form.baptized_this_month'.tr(),
                  ),
                  _NumberField(
                    controller: _baptizedTotal,
                    label: 'monthly_reports.form.total_baptized'.tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MonthlyReportEntrance(
              index: 3,
              child: _FormSection(
                title: 'monthly_reports.form.service_title'.tr(),
                eyebrow: 'monthly_reports.form.service_eyebrow'.tr(),
                description: 'monthly_reports.form.service_description'.tr(),
                icon: HugeIcons.strokeRoundedNoteEdit,
                children: [
                  _LongTextField(
                    controller: _participation,
                    label: 'monthly_reports.form.club_participation'.tr(),
                    hint: 'monthly_reports.form.club_participation_hint'.tr(),
                  ),
                  _LongTextField(
                    controller: _service,
                    label: 'monthly_reports.form.community_service'.tr(),
                    hint: 'monthly_reports.form.community_service_hint'.tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MonthlyReportEntrance(
              index: 4,
              child: _FormSection(
                title: 'monthly_reports.form.materials_title'.tr(),
                eyebrow: 'monthly_reports.form.materials_eyebrow'.tr(),
                description: 'monthly_reports.form.materials_description'.tr(),
                icon: HugeIcons.strokeRoundedNoteEdit,
                children: [
                  _ReportSwitch(
                    title: 'monthly_reports.form.certificates'.tr(),
                    subtitle: 'monthly_reports.form.certificates_helper'.tr(),
                    value: _certificates,
                    onChanged: (v) => setState(() => _certificates = v),
                  ),
                  _ReportSwitch(
                    title: 'monthly_reports.form.booklets'.tr(),
                    subtitle: 'monthly_reports.form.booklets_helper'.tr(),
                    value: _booklets,
                    onChanged: (v) => setState(() => _booklets = v),
                  ),
                  _ReportSwitch(
                    title: 'monthly_reports.form.booklets_signed'.tr(),
                    subtitle:
                        'monthly_reports.form.booklets_signed_helper'.tr(),
                    value: _bookletsSigned,
                    onChanged: (v) => setState(() => _bookletsSigned = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: SacButton.primary(
            key: ValueKey(state.isLoading),
            text: state.isLoading
                ? 'common.saving'.tr()
                : 'monthly_reports.form.save'.tr(),
            icon: HugeIcons.strokeRoundedNoteEdit,
            onPressed: state.isLoading ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _FormIntroCard extends StatelessWidget {
  final MonthlyReport report;

  const _FormIntroCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${report.monthName} ${report.year}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'monthly_reports.form.intro_title'.tr(),
            style: TextStyle(
              color: c.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'monthly_reports.form.intro_body'.tr(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final String eyebrow;
  final String description;
  final dynamic icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(icon: icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            description,
            style:
                TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border.withValues(alpha: 0.75)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SacTextField(
      controller: controller,
      label: label,
      hint: '0',
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      prefixIcon: HugeIcons.strokeRoundedAnalytics01,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      margin: const EdgeInsets.only(bottom: 14),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < 0) {
          return 'monthly_reports.form.number_error'.tr();
        }
        return null;
      },
    );
  }
}

class _LongTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _LongTextField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return SacTextField(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: 5,
      maxLength: 2000,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      prefixIcon: HugeIcons.strokeRoundedNoteEdit,
      margin: const EdgeInsets.only(bottom: 14),
    );
  }
}

class _ReportSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReportSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      label: title,
      value: value ? 'common.yes'.tr() : 'common.no'.tr(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

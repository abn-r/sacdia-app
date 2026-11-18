import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';

import '../../domain/entities/monthly_report.dart';
import '../providers/monthly_reports_providers.dart';
import '../utils/monthly_report_format.dart';
import '../widgets/monthly_report_form_rows.dart';
import '../widgets/monthly_report_motion.dart';
import '../widgets/monthly_report_save_status.dart';

/// Tiempo sin tocar nada antes de guardar solo.
const Duration kMonthlyReportAutosaveDelay = Duration(milliseconds: 700);

enum _Count {
  planning('planning_meetings'),
  parents('parent_meetings'),
  youth('youth_council_attendance'),
  church('church_board_attendance'),
  soulTarget('soul_target'),
  unbaptized('unbaptized_members'),
  studies('bible_studies_receiving'),
  baptizedMonth('baptized_this_month'),
  baptizedTotal('total_baptized');

  const _Count(this.labelKey);
  final String labelKey;
}

enum _Flag {
  weekly('weekly_instruction'),
  studiesGiven('studies_given'),
  literature('literature'),
  certificates('certificates'),
  booklets('booklets'),
  bookletsSigned('booklets_signed');

  const _Flag(this.labelKey);
  final String labelKey;
}

enum _Text {
  participation('club_participation', 'club_participation_hint'),
  service('community_service', 'community_service_hint');

  const _Text(this.labelKey, this.hintKey);
  final String labelKey;
  final String hintKey;
}

/// Qué campos tiene cada sección, en orden.
List<Enum> _fieldsOf(MonthlyReportManualSection section) {
  switch (section) {
    case MonthlyReportManualSection.meetings:
      return [_Count.planning, _Count.parents, _Count.youth, _Count.church];
    case MonthlyReportManualSection.mission:
      return [
        _Count.soulTarget,
        _Count.unbaptized,
        _Count.studies,
        _Flag.weekly,
        _Flag.studiesGiven,
        _Flag.literature,
        _Count.baptizedMonth,
        _Count.baptizedTotal,
      ];
    case MonthlyReportManualSection.service:
      return [_Text.participation, _Text.service];
    case MonthlyReportManualSection.materials:
      return [_Flag.certificates, _Flag.booklets, _Flag.bookletsSigned];
  }
}

/// Month names are capitalized for titles; es, fr and pt-BR write them in
/// lowercase mid-sentence. English keeps the capital.
String _midSentenceMonth(String name, Locale locale) =>
    locale.languageCode == 'en' ? name : name.toLowerCase();

int? _previousCount(_Count count, MonthlyReportManualData data) {
  switch (count) {
    case _Count.planning:
      return data.planningMeetings;
    case _Count.parents:
      return data.parentMeetings;
    case _Count.youth:
      return data.youthCouncilAttendance;
    case _Count.church:
      return data.churchBoardAttendance;
    case _Count.soulTarget:
      return data.soulTarget;
    case _Count.unbaptized:
      return data.unbaptizedMembers;
    case _Count.studies:
      return data.bibleStudiesReceiving;
    case _Count.baptizedMonth:
      return data.baptizedThisMonth;
    case _Count.baptizedTotal:
      return data.totalBaptized;
  }
}

/// Una sección de los datos manuales en una hoja. Se guarda sola poco después
/// de cada cambio; «Listo» vuelve al índice del informe.
class MonthlyReportManualDataFormView extends ConsumerStatefulWidget {
  final MonthlyReport report;
  final MonthlyReportManualSection section;

  const MonthlyReportManualDataFormView({
    super.key,
    required this.report,
    required this.section,
  });

  /// Abre la hoja de [section]. Devuelve `true` si se guardó algo.
  ///
  /// No se cierra arrastrando ni tocando fuera: cada cierre pasa por «Listo»,
  /// la X o atrás, que primero terminan de guardar.
  static Future<bool?> show(
    BuildContext context,
    MonthlyReport report, {
    required MonthlyReportManualSection section,
  }) {
    return showSacSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => MonthlyReportManualDataFormView(
        report: report,
        section: section,
      ),
    );
  }

  @override
  ConsumerState<MonthlyReportManualDataFormView> createState() =>
      _MonthlyReportManualDataFormViewState();
}

class _MonthlyReportManualDataFormViewState
    extends ConsumerState<MonthlyReportManualDataFormView> {
  final Map<_Count, int> _counts = {};
  final Map<_Flag, bool> _flags = {};
  late final TextEditingController _participation;
  late final TextEditingController _service;

  Timer? _debounce;
  Future<bool>? _inFlight;
  bool _dirty = false;
  bool _everSaved = false;
  MonthlyReportSaveState _saveState = MonthlyReportSaveState.idle;

  @override
  void initState() {
    super.initState();
    final data = widget.report.manualData;
    _counts.addAll({
      _Count.planning: data?.planningMeetings ?? 0,
      _Count.parents: data?.parentMeetings ?? 0,
      _Count.youth: data?.youthCouncilAttendance ?? 0,
      _Count.church: data?.churchBoardAttendance ?? 0,
      _Count.soulTarget: data?.soulTarget ?? 0,
      _Count.unbaptized: data?.unbaptizedMembers ?? 0,
      _Count.studies: data?.bibleStudiesReceiving ?? 0,
      _Count.baptizedMonth: data?.baptizedThisMonth ?? 0,
      _Count.baptizedTotal: data?.totalBaptized ?? 0,
    });
    _flags.addAll({
      _Flag.weekly: data?.hasWeeklyBibleInstruction ?? false,
      _Flag.studiesGiven: data?.bibleStudiesGiven ?? false,
      _Flag.literature: data?.literatureDistributed ?? false,
      _Flag.certificates: data?.certificatesDelivered ?? false,
      _Flag.booklets: data?.membersHaveBooklet ?? false,
      _Flag.bookletsSigned: data?.bookletRequirementsSigned ?? false,
    });
    _participation =
        TextEditingController(text: data?.clubParticipationDescription ?? '');
    _service =
        TextEditingController(text: data?.communityServiceDescription ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _participation.dispose();
    _service.dispose();
    super.dispose();
  }

  MonthlyReportManualData _buildData() {
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    return MonthlyReportManualData(
      planningMeetings: _counts[_Count.planning],
      parentMeetings: _counts[_Count.parents],
      youthCouncilAttendance: _counts[_Count.youth],
      churchBoardAttendance: _counts[_Count.church],
      soulTarget: _counts[_Count.soulTarget],
      unbaptizedMembers: _counts[_Count.unbaptized],
      bibleStudiesReceiving: _counts[_Count.studies],
      hasWeeklyBibleInstruction: _flags[_Flag.weekly],
      bibleStudiesGiven: _flags[_Flag.studiesGiven],
      literatureDistributed: _flags[_Flag.literature],
      baptizedThisMonth: _counts[_Count.baptizedMonth],
      totalBaptized: _counts[_Count.baptizedTotal],
      clubParticipationDescription: text(_participation),
      communityServiceDescription: text(_service),
      certificatesDelivered: _flags[_Flag.certificates],
      membersHaveBooklet: _flags[_Flag.booklets],
      bookletRequirementsSigned: _flags[_Flag.bookletsSigned],
    );
  }

  /// Marca el cambio y programa el guardado.
  void _changed([VoidCallback? update]) {
    setState(() {
      update?.call();
      _dirty = true;
      _saveState = MonthlyReportSaveState.saving;
    });
    _debounce?.cancel();
    _debounce = Timer(kMonthlyReportAutosaveDelay, _save);
  }

  Future<bool> _save() {
    _debounce?.cancel();
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<bool> _run() async {
    var ok = true;
    while (_dirty && ok) {
      if (!mounted) return false;
      _dirty = false;
      setState(() => _saveState = MonthlyReportSaveState.saving);
      ok = await ref
          .read(monthlyReportMutationProvider.notifier)
          .saveManualData(widget.report.id, _buildData(), refresh: false);
      if (ok) {
        _everSaved = true;
      } else {
        _dirty = true;
      }
      if (!mounted) return ok;
    }
    setState(() => _saveState =
        ok ? MonthlyReportSaveState.saved : MonthlyReportSaveState.error);
    return ok;
  }

  /// Termina de guardar lo pendiente. `false` si no se pudo.
  Future<bool> _flush() async {
    _debounce?.cancel();
    final running = _inFlight;
    if (running != null) await running;
    if (!mounted) return false;
    if (_dirty) return _save();
    return _saveState != MonthlyReportSaveState.error;
  }

  bool get _hasUnsaved =>
      _dirty || _inFlight != null || _saveState == MonthlyReportSaveState.error;

  Future<void> _done() async {
    final navigator = Navigator.of(context);
    if (await _flush() && mounted) navigator.pop(_everSaved);
  }

  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (await _flush()) {
      if (mounted) navigator.pop(_everSaved);
      return;
    }
    if (!mounted) return;
    final discard = await SacDialog.show(
      context,
      title: 'monthly_reports.form.discard_title'.tr(),
      content: 'monthly_reports.form.discard_body'.tr(),
      cancelLabel: 'monthly_reports.form.discard_keep'.tr(),
      confirmLabel: 'monthly_reports.form.discard_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (discard == true && mounted) navigator.pop(_everSaved);
  }

  String? _hintFor(_Count count, MonthlyReportManualData? previous) {
    if (previous == null) return null;
    final value = _previousCount(count, previous);
    if (value == null) return null;
    final report = widget.report;
    final month = report.month == 1 ? 12 : report.month - 1;
    final year = report.month == 1 ? report.year - 1 : report.year;
    final locale = Localizations.localeOf(context).toString();
    return 'monthly_reports.form.previous_hint'.tr(namedArgs: {
      'month': DateFormat.MMM(locale).format(DateTime(year, month)),
      'value': '$value',
    });
  }

  Widget _rowFor(Enum field, MonthlyReportManualData? previous) {
    if (field is _Count) {
      return MonthlyReportStepperRow(
        key: ValueKey('monthly-report-field-${field.name}'),
        label: 'monthly_reports.form.${field.labelKey}'.tr(),
        value: _counts[field] ?? 0,
        previousHint: _hintFor(field, previous),
        onChanged: (next) => _changed(() => _counts[field] = next),
      );
    }
    if (field is _Flag) {
      return MonthlyReportSwitchRow(
        key: ValueKey('monthly-report-field-${field.name}'),
        label: 'monthly_reports.form.${field.labelKey}'.tr(),
        value: _flags[field] ?? false,
        onChanged: (next) => _changed(() => _flags[field] = next),
      );
    }
    final text = field as _Text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SacTextField(
        key: ValueKey('monthly-report-field-${text.name}'),
        controller: text == _Text.participation ? _participation : _service,
        label: 'monthly_reports.form.${text.labelKey}'.tr(),
        hint: 'monthly_reports.form.${text.hintKey}'.tr(),
        maxLines: 5,
        maxLength: 2000,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => _changed(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final report = widget.report;
    final section = widget.section;
    final previous = ref
        .watch(
          monthlyReportPreviousManualDataProvider((
            enrollmentId: report.enrollmentId,
            month: report.month,
            year: report.year,
          )),
        )
        .value;
    final fields = _fieldsOf(section);
    final isText = fields.first is _Text;

    return PopScope(
      canPop: !_hasUnsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.94,
            child: Material(
              color: c.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SacSheetHeader(
                    title: monthlyReportSectionTitle(section),
                    subtitleWidget: MonthlyReportSaveStatusLine(
                      state: _saveState,
                      onRetry: () {
                        _dirty = true;
                        _save();
                      },
                    ),
                    actions: [
                      SacPressable(
                        listenOnly: true,
                        child: IconButton(
                          enableFeedback: false,
                          tooltip: 'common.close'.tr(),
                          onPressed: _close,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 22,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        MonthlyReportEntrance(
                          child: SacGroupedSection(
                            label: 'monthly_reports.form.this_month'.tr(),
                            action: const SizedBox.shrink(),
                            dividerIndent: 16,
                            children: [
                              for (final field in fields)
                                _rowFor(field, previous),
                              if (isText) const SizedBox(height: 14),
                            ],
                          ),
                        ),
                        if (!isText)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                            child: Text(
                              'monthly_reports.form.month_note'.tr(
                                namedArgs: {
                                  'month': _midSentenceMonth(
                                    report.monthName,
                                    Localizations.localeOf(context),
                                  ),
                                },
                              ),
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                height: 1.35,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  MonthlyReportFrostBar(
                    child: SacButton.primary(
                      key: const Key('monthly-report-form-done'),
                      text: 'common.done'.tr(),
                      icon: HugeIcons.strokeRoundedTick02,
                      onPressed: _done,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../../core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_notice.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../activities/presentation/views/location_picker_view.dart';
import '../../../activities/presentation/widgets/activity_form_widgets.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_providers.dart';
import '../widgets/enrollment_board_summary.dart';
import '../../../../core/animations/page_transitions.dart';
import '../../../../core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla para crear o actualizar el registro anual del club.
//
// Campos:
//   - Dirección del lugar de reunión (con selector de mapa)
//   - Días de reunión con horario por día
//   - Almas (objetivo de nuevos miembros)
//   - Cuota (toggle si el club cobra cuota)
//   - Directivos (solo lectura: se toman de los cargos de Miembros)
// ─────────────────────────────────────────────────────────────────────────────

/// Días de la semana disponibles (valores canónicos para el backend).
const _kWeekDays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String _dayLabel(String day) {
  switch (day) {
    case 'Lunes':
      return 'enrollment.form.days.monday'.tr();
    case 'Martes':
      return 'enrollment.form.days.tuesday'.tr();
    case 'Miércoles':
      return 'enrollment.form.days.wednesday'.tr();
    case 'Jueves':
      return 'enrollment.form.days.thursday'.tr();
    case 'Viernes':
      return 'enrollment.form.days.friday'.tr();
    case 'Sábado':
      return 'enrollment.form.days.saturday'.tr();
    case 'Domingo':
      return 'enrollment.form.days.sunday'.tr();
    default:
      return day;
  }
}

/// Pantalla para crear o actualizar el registro anual del club.
class EnrollmentFormView extends ConsumerStatefulWidget {
  final String clubId;
  final int sectionId;

  /// Si se pasa, opera en modo edición (PATCH).
  final String? enrollmentId;
  final String? initialAddress;
  final double? initialLat;
  final double? initialLong;
  final List<MeetingSchedule>? initialMeetingSchedule;
  final int? initialSoulsTarget;
  final bool? initialFee;
  final double? initialFeeAmount;

  /// Reviewer's reason when fixing a rejected enrollment; shown at the top.
  final String? rejectionReason;

  const EnrollmentFormView({
    super.key,
    required this.clubId,
    required this.sectionId,
    this.enrollmentId,
    this.initialAddress,
    this.initialLat,
    this.initialLong,
    this.initialMeetingSchedule,
    this.initialSoulsTarget,
    this.initialFee,
    this.initialFeeAmount,
    this.rejectionReason,
  });

  @override
  ConsumerState<EnrollmentFormView> createState() => _EnrollmentFormViewState();
}

class _EnrollmentFormViewState extends ConsumerState<EnrollmentFormView> {
  final _formKey = GlobalKey<FormState>();
  final _soulsCtrl = TextEditingController();
  final _feeAmountCtrl = TextEditingController();

  // Ubicación del lugar de reunión
  LocationPickerResult? _selectedLocation;
  bool _locationTouched = false;

  // Días + horarios de reunión
  // Mapa: día -> tiempo (String HH:mm)
  final Map<String, String> _meetingSchedule = {};

  // Campos nuevos
  bool _fee = false;

  bool get _isEdit => widget.enrollmentId != null;

  @override
  void initState() {
    super.initState();

    // Dirección y ubicación
    if (widget.initialAddress != null &&
        widget.initialLat != null &&
        widget.initialLong != null) {
      _selectedLocation = LocationPickerResult(
        name: widget.initialAddress!,
        lat: widget.initialLat!,
        long: widget.initialLong!,
      );
    }

    // Días de reunión con horario
    if (widget.initialMeetingSchedule != null) {
      for (final s in widget.initialMeetingSchedule!) {
        _meetingSchedule[s.day] = s.time;
      }
    }

    // Otros campos
    _fee = widget.initialFee ?? false;
    _soulsCtrl.text = widget.initialSoulsTarget?.toString() ?? '';
    if (widget.initialFeeAmount != null) {
      _feeAmountCtrl.text = widget.initialFeeAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _soulsCtrl.dispose();
    _feeAmountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showError(String message) {
    SacSnackBar.show(context, message, isError: true);
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      SacSlideUpRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.lat, _selectedLocation!.long)
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _locationTouched = true;
      });
    }
  }

  Future<void> _pickTimeForDay(String day) async {
    final currentTime = _meetingSchedule[day];
    final parts = currentTime?.split(':') ?? ['9', '0'];
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePickerSheet(context, initial);
    if (picked != null && mounted) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => _meetingSchedule[day] = '$hh:$mm');
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_meetingSchedule.containsKey(day)) {
        _meetingSchedule.remove(day);
      } else {
        _meetingSchedule[day] = '09:00';
      }
    });
  }

  List<MeetingSchedule> get _meetingScheduleList {
    return _meetingSchedule.entries
        .map((e) => MeetingSchedule(day: e.key, time: e.value))
        .toList();
  }

  Future<void> _submit() async {
    setState(() => _locationTouched = true);

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (_selectedLocation == null) {
      _showError('enrollment.form.error_location_required'.tr());
      return;
    }
    if (_meetingSchedule.isEmpty) {
      _showError('enrollment.form.error_days_required'.tr());
      return;
    }

    final notifier = ref.read(enrollmentFormProvider.notifier);
    final soulsText = _soulsCtrl.text.trim();
    final soulsTarget = soulsText.isNotEmpty ? int.tryParse(soulsText) : null;
    final feeAmountText = _feeAmountCtrl.text.trim();
    final feeAmount = _fee && feeAmountText.isNotEmpty
        ? double.tryParse(feeAmountText)
        : null;

    bool success;

    if (_isEdit) {
      success = await notifier.update(
        clubId: widget.clubId,
        sectionId: widget.sectionId,
        enrollmentId: widget.enrollmentId!,
        address: _selectedLocation!.name,
        lat: _selectedLocation!.lat,
        long: _selectedLocation!.long,
        meetingSchedule: _meetingScheduleList,
        soulsTarget: soulsTarget,
        feeAmount: feeAmount,
        fee: _fee,
      );
    } else {
      success = await notifier.create(
        clubId: widget.clubId,
        sectionId: widget.sectionId,
        address: _selectedLocation!.name,
        lat: _selectedLocation!.lat,
        long: _selectedLocation!.long,
        meetingSchedule: _meetingScheduleList,
        soulsTarget: soulsTarget,
        fee: _fee,
        feeAmount: feeAmount,
      );
    }

    if (!mounted) return;

    if (success) {
      SacSnackBar.show(
          context,
          _isEdit
              ? 'enrollment.form.success_updated'.tr()
              : 'enrollment.form.success_created'.tr(),
          isSuccess: true);
      Navigator.of(context).pop(true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(enrollmentFormProvider);
    final membersAsync = ref.watch(membersNotifierProvider);
    final c = context.sac;

    final members = membersAsync.value?.members ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: _isEdit
              ? 'enrollment.form.title_edit'.tr()
              : 'enrollment.form.title_create'.tr(),
          automaticallyImplyLeading: !formState.isLoading,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Form(
            key: _formKey,
            child: ListView(
              padding:
                  SacTopBar.paddingBelowBar(context, const EdgeInsets.all(20)),
              children: [
                if (widget.rejectionReason != null) ...[
                  SacNotice(
                    tone: SacNoticeTone.error,
                    text: tr(
                      'enrollment.status.rejection_reason',
                      namedArgs: {'reason': widget.rejectionReason!},
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // ── Sección: Lugar de reunión ────────────────────────────────
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedLocation03,
                  label: 'enrollment.form.section_location'.tr(),
                ),
                const SizedBox(height: 12),

                // Selector de ubicación con mapa
                _LocationPickerField(
                  result: _selectedLocation,
                  hasError: _locationTouched && _selectedLocation == null,
                  enabled: !formState.isLoading,
                  onTap: formState.isLoading ? null : _openLocationPicker,
                ),
                const SizedBox(height: 24),

                // ── Sección: Días y horarios de reunión ──────────────────────
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  label: 'enrollment.form.section_schedule'.tr(),
                ),
                const SizedBox(height: 4),
                Text(
                  'enrollment.form.schedule_hint'.tr(),
                  style: TextStyle(
                      fontSize: SacFontSize.bodySmall, color: c.textTertiary),
                ),
                const SizedBox(height: 12),

                // Chips de días
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kWeekDays.map((day) {
                    final isSelected = _meetingSchedule.containsKey(day);
                    final time = _meetingSchedule[day];
                    return _DayScheduleChip(
                      day: _dayLabel(day),
                      isSelected: isSelected,
                      time: time,
                      enabled: !formState.isLoading,
                      onTapDay: () => _toggleDay(day),
                      onTapTime: isSelected ? () => _pickTimeForDay(day) : null,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ── Sección: Datos del club ──────────────────────────────────
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  label: 'enrollment.form.section_club_data'.tr(),
                ),
                const SizedBox(height: 12),

                // Almas (objetivo)
                _FieldLabel(label: 'enrollment.form.label_souls_target'.tr()),
                const SizedBox(height: 8),
                SacTextField(
                  controller: _soulsCtrl,
                  enabled: !formState.isLoading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  hint: 'enrollment.form.hint_souls'.tr(),
                  prefixIcon: HugeIcons.strokeRoundedUserAdd01,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 20),

                // Cuota (toggle)
                _ToggleRow(
                  icon: HugeIcons.strokeRoundedCreditCard,
                  label: 'enrollment.form.label_fee_toggle'.tr(),
                  subtitle: 'enrollment.form.subtitle_fee_toggle'.tr(),
                  value: _fee,
                  enabled: !formState.isLoading,
                  onChanged: (v) => setState(() {
                    _fee = v;
                    if (!v) _feeAmountCtrl.clear();
                  }),
                ),

                // Monto de cuota (visible solo cuando el toggle está activo)
                if (_fee) ...[
                  const SizedBox(height: 12),
                  _FieldLabel(label: 'enrollment.form.label_fee_amount'.tr()),
                  const SizedBox(height: 8),
                  SacTextField(
                    controller: _feeAmountCtrl,
                    enabled: !formState.isLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [
                      // Allow digits and a single decimal point
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    hint: 'enrollment.form.hint_fee_amount'.tr(),
                    prefixText: '\$',
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (!_fee) return null;
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'enrollment.form.error_fee_amount_required'.tr();
                      }
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) {
                        return 'enrollment.form.error_fee_amount_positive'.tr();
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // ── Sección: Directivos (solo lectura) ───────────────────────
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  label: 'enrollment.form.section_leadership'.tr(),
                ),
                const SizedBox(height: 12),
                EnrollmentBoardSummary(
                  members: members,
                  isLoading: membersAsync.isLoading && !membersAsync.hasValue,
                  onOpenMembers: formState.isLoading
                      ? null
                      : () => context.push(RouteNames.homeMembers),
                ),

                const SizedBox(height: 24),

                // ── Error ────────────────────────────────────────────────────
                if (formState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          color: c.onErrorContainer,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formState.errorMessage!,
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              color: c.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Submit ───────────────────────────────────────────────────
                SacButton.primary(
                  text: widget.rejectionReason != null
                      ? 'enrollment.form.button_resubmit'.tr()
                      : _isEdit
                          ? 'enrollment.form.button_save_changes'.tr()
                          : 'enrollment.form.button_enroll'.tr(),
                  icon: _isEdit
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedUserAdd01,
                  isLoading: formState.isLoading,
                  onPressed: formState.isLoading ? null : _submit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos
// ─────────────────────────────────────────────────────────────────────────────

/// Encabezado de sección con icono.
class _SectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        HugeIcon(icon: icon, color: SacAccent.of(context).color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: SacFontSize.titleSmall,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: c.border, height: 1)),
      ],
    );
  }
}

/// Etiqueta de campo.
class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Text(
      label,
      style: TextStyle(
        fontSize: SacFontSize.bodyMedium,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
    );
  }
}

/// Botón tappable que abre el selector de ubicación en el mapa.
class _LocationPickerField extends StatelessWidget {
  final LocationPickerResult? result;
  final bool hasError;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocationPickerField({
    required this.result,
    required this.hasError,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasResult = result != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: hasError
                ? AppColors.error
                : hasResult
                    ? SacAccent.of(context).color
                    : c.border,
            width: hasResult || hasError ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLocation01,
              color: hasError
                  ? AppColors.error
                  : hasResult
                      ? SacAccent.of(context).color
                      : c.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasResult
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result!.name,
                          style: TextStyle(
                            fontSize: SacFontSize.titleSmall,
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result!.lat.toStringAsFixed(5)}, ${result!.long.toStringAsFixed(5)}',
                          style: TextStyle(
                              fontSize: SacFontSize.labelSmall,
                              color: c.textTertiary),
                        ),
                      ],
                    )
                  : Text(
                      hasError
                          ? 'enrollment.form.location_error_hint'.tr()
                          : 'enrollment.form.location_hint'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        color: hasError ? AppColors.error : c.textTertiary,
                      ),
                    ),
            ),
            HugeIcon(
              icon: hasResult
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedArrowRight01,
              color: hasResult ? SacAccent.of(context).color : c.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de día con horario. Muestra el día como chip seleccionable.
/// Cuando está seleccionado, muestra el horario como un sub-chip tappable.
class _DayScheduleChip extends StatelessWidget {
  final String day;
  final bool isSelected;
  final String? time;
  final bool enabled;
  final VoidCallback onTapDay;
  final VoidCallback? onTapTime;

  const _DayScheduleChip({
    required this.day,
    required this.isSelected,
    required this.time,
    required this.enabled,
    required this.onTapDay,
    this.onTapTime,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    if (!isSelected) {
      // Chip no seleccionado
      return GestureDetector(
        onTap: enabled ? onTapDay : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: c.border, width: 1.5),
          ),
          child: Text(
            day,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
        ),
      );
    }

    // Chip seleccionado: muestra día + horario
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: SacAccent.of(context).color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: SacAccent.of(context).color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre del día (tappable para deseleccionar)
          GestureDetector(
            onTap: enabled ? onTapDay : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: SacAccent.of(context).color,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w700,
                      color: SacAccent.of(context).color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Separador
          Container(
            width: 1,
            height: 24,
            color: SacAccent.of(context).color.withValues(alpha: 0.3),
          ),
          // Horario (tappable para cambiar la hora)
          GestureDetector(
            onTap: enabled ? onTapTime : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: SacAccent.of(context).color.withValues(alpha: 0.7),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time ?? '09:00',
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      fontWeight: FontWeight.w600,
                      color:
                          SacAccent.of(context).color.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de toggle (Switch) con icono, título y subtítulo.
class _ToggleRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: value ? SacAccent.of(context).color : c.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary),
                  ),
              ],
            ),
          ),
          SacPressable(
            listenOnly: true,
            child: Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: SacAccent.of(context).color,
              activeTrackColor:
                  SacAccent.of(context).color.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

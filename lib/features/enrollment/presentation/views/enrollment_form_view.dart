import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../activities/presentation/views/location_picker_view.dart';
import '../../../activities/presentation/widgets/activity_form_widgets.dart';
import '../../../members/domain/entities/club_member.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/enrollment.dart';
import '../providers/enrollment_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla para crear o actualizar la inscripción anual al club.
//
// Campos:
//   - Dirección del lugar de reunión (con selector de mapa)
//   - Días de reunión con horario por día
//   - Almas (objetivo de nuevos miembros)
//   - Cuota (toggle si el club cobra cuota)
//   - Director (read-only, el usuario actual con rol director)
//   - Subdirector (multi-select, hasta 2)
//   - Secretario (single-select)
//   - Tesorero (single-select)
//   - Secretario-Tesorero (condicional: solo si el club tiene ese rol;
//     mutuamente exclusivo con Secretario y Tesorero por separado)
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

/// Pantalla para crear o actualizar la inscripción anual al club.
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
  final String? initialDirectorId;
  final List<String>? initialDeputyDirectorIds;
  final String? initialSecretaryId;
  final String? initialTreasurerId;
  final String? initialSecretaryTreasurerId;

  /// Si `true`, el club permite el rol secretario-tesorero (mutuamente
  /// exclusivo con secretario + tesorero individuales).
  final bool hasSecretaryTreasurerRole;

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
    this.initialDirectorId,
    this.initialDeputyDirectorIds,
    this.initialSecretaryId,
    this.initialTreasurerId,
    this.initialSecretaryTreasurerId,
    this.hasSecretaryTreasurerRole = false,
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

  // Whether auto-population of roles from members has been done
  bool _rolesAutoPopulated = false;

  // Días + horarios de reunión
  // Mapa: día -> tiempo (String HH:mm)
  final Map<String, String> _meetingSchedule = {};

  // Campos nuevos
  bool _fee = false;
  List<String> _deputyDirectorIds = [];
  String? _secretaryId;
  String? _treasurerId;
  String? _secretaryTreasurerId;

  bool get _isEdit => widget.enrollmentId != null;

  // Indica si se usa el campo combinado secretario-tesorero
  bool get _useSecretaryTreasurer =>
      widget.hasSecretaryTreasurerRole && _secretaryTreasurerId != null;

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
    _deputyDirectorIds = List.from(widget.initialDeputyDirectorIds ?? []);
    _secretaryId = widget.initialSecretaryId;
    _treasurerId = widget.initialTreasurerId;
    _secretaryTreasurerId = widget.initialSecretaryTreasurerId;

    // Auto-populate roles: if members are already loaded, do it immediately;
    // otherwise schedule a post-frame check. Only applies to new enrollments
    // where no initial role IDs were provided.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoPopulateRoles();
    });
  }

  /// Attempts to auto-populate leadership roles from the current member list.
  /// Only runs once and only when no initial role values were provided (new
  /// enrollment or enrollment without pre-assigned roles).
  void _tryAutoPopulateRoles() {
    if (_rolesAutoPopulated) return;

    final membersData = ref.read(membersNotifierProvider).valueOrNull;
    if (membersData == null) {
      // Data not ready yet — listen and retry via didChangeDependencies
      return;
    }

    _rolesAutoPopulated = true;
    _autoPopulateRoles(membersData.members);
  }

  void _autoPopulateRoles(List<ClubMember> members) {
    if (members.isEmpty) return;

    String? newSecretaryId = _secretaryId;
    String? newTreasurerId = _treasurerId;
    String? newSecretaryTreasurerId = _secretaryTreasurerId;
    List<String> newDeputyIds = List.from(_deputyDirectorIds);

    for (final member in members) {
      final role = member.clubRole?.toLowerCase().trim() ?? '';

      // Deputy directors (up to 2).
      // Canonical backend value is 'deputy_director' (underscore). We also
      // match the hyphenated form 'deputy-director' and the Spanish alias
      // 'subdirector' / 'sub_director' as defensive fallbacks.
      if ((role == 'deputy_director' ||
              role == 'deputy-director' ||
              role.contains('deputy') ||
              role.contains('subdirector') ||
              role.contains('sub_director')) &&
          newDeputyIds.length < 2 &&
          !newDeputyIds.contains(member.userId)) {
        newDeputyIds.add(member.userId);
      }

      // Secretary
      if (role == 'secretary' && newSecretaryId == null) {
        newSecretaryId = member.userId;
      }

      // Treasurer
      if (role == 'treasurer' && newTreasurerId == null) {
        newTreasurerId = member.userId;
      }

      // Secretary-Treasurer (combined role)
      if ((role == 'secretary_treasurer' ||
              role.contains('secretario_tesorero') ||
              role.contains('secretary-treasurer')) &&
          newSecretaryTreasurerId == null &&
          widget.hasSecretaryTreasurerRole) {
        newSecretaryTreasurerId = member.userId;
      }
    }

    final deputyChanged = !_listsEqual(newDeputyIds, _deputyDirectorIds);
    final changed = deputyChanged ||
        newSecretaryId != _secretaryId ||
        newTreasurerId != _treasurerId ||
        newSecretaryTreasurerId != _secretaryTreasurerId;

    if (changed && mounted) {
      setState(() {
        _deputyDirectorIds = newDeputyIds;
        _secretaryId = newSecretaryId;
        _treasurerId = newTreasurerId;
        if (widget.hasSecretaryTreasurerRole &&
            newSecretaryTreasurerId != null) {
          // Activating secretary-treasurer clears individual roles
          _secretaryTreasurerId = newSecretaryTreasurerId;
          _secretaryId = null;
          _treasurerId = null;
        }
      });
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _soulsCtrl.dispose();
    _feeAmountCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retry role auto-population when provider data becomes available
    if (!_rolesAutoPopulated) {
      _tryAutoPopulateRoles();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerView(
          initialLocation: _selectedLocation != null
              ? LatLng(_selectedLocation!.lat, _selectedLocation!.long)
              : null,
        ),
        fullscreenDialog: true,
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
    final feeAmount =
        _fee && feeAmountText.isNotEmpty ? double.tryParse(feeAmountText) : null;

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
        directorId: null, // director se resuelve del contexto, no se edita aqui
        deputyDirectorIds: _deputyDirectorIds,
        secretaryId: _useSecretaryTreasurer ? null : _secretaryId,
        treasurerId: _useSecretaryTreasurer ? null : _treasurerId,
        secretaryTreasurerId: widget.hasSecretaryTreasurerRole
            ? _secretaryTreasurerId
            : null,
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
        directorId: null,
        deputyDirectorIds: _deputyDirectorIds,
        secretaryId: _useSecretaryTreasurer ? null : _secretaryId,
        treasurerId: _useSecretaryTreasurer ? null : _treasurerId,
        secretaryTreasurerId: widget.hasSecretaryTreasurerRole
            ? _secretaryTreasurerId
            : null,
      );
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'enrollment.form.success_updated'.tr()
              : 'enrollment.form.success_created'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(enrollmentFormProvider);
    final membersAsync = ref.watch(membersNotifierProvider);
    final clubCtxAsync = ref.watch(clubContextProvider);
    final c = context.sac;

    // When members finish loading, auto-populate roles (runs once per session)
    ref.listen<AsyncValue<MembersData>>(membersNotifierProvider, (_, next) {
      if (!_rolesAutoPopulated) {
        final data = next.valueOrNull;
        if (data != null) {
          _rolesAutoPopulated = true;
          _autoPopulateRoles(data.members);
        }
      }
    });

    final members = membersAsync.valueOrNull?.members ?? [];
    final currentUserCtx = clubCtxAsync.valueOrNull;

    // El director es el usuario actual con rol director (display-only)
    final directorMember = currentUserCtx?.isDirector == true
        ? members.where((m) =>
            m.clubRole?.toLowerCase().contains('director') == true &&
            !m.clubRole!.toLowerCase().contains('sub') &&
            !m.clubRole!.toLowerCase().contains('vice') &&
            !m.clubRole!.toLowerCase().contains('deputy')).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEdit ? 'enrollment.form.title_edit'.tr() : 'enrollment.form.title_create'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: formState.isLoading ? null : () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                fontSize: 12,
                color: c.textTertiary,
              ),
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
                  onTapTime: isSelected
                      ? () => _pickTimeForDay(day)
                      : null,
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
            TextFormField(
              controller: _soulsCtrl,
              enabled: !formState.isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(
                c,
                hintText: 'enrollment.form.hint_souls'.tr(),
                prefixIcon: HugeIcons.strokeRoundedUserAdd01,
              ),
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
              TextFormField(
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
                decoration: _inputDecoration(
                  c,
                  hintText: 'enrollment.form.hint_fee_amount'.tr(),
                  prefixIcon: HugeIcons.strokeRoundedMoney01,
                ).copyWith(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
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

            // ── Sección: Directivos ──────────────────────────────────────
            _SectionHeader(
              icon: HugeIcons.strokeRoundedUserGroup,
              label: 'enrollment.form.section_leadership'.tr(),
            ),
            const SizedBox(height: 12),

            // Director (solo lectura — viene del contexto)
            _FieldLabel(label: 'enrollment.form.label_director'.tr()),
            const SizedBox(height: 8),
            _ReadOnlyMemberField(
              member: directorMember,
              placeholder: 'enrollment.form.placeholder_director'.tr(),
            ),

            const SizedBox(height: 20),

            // Subdirector (multi, hasta 2)
            _FieldLabel(
              label: 'enrollment.form.label_deputy_directors'.tr(),
              badge: '${_deputyDirectorIds.length}/2',
            ),
            const SizedBox(height: 8),
            _MultiMemberSelector(
              selectedIds: _deputyDirectorIds,
              members: members,
              maxCount: 2,
              placeholder: 'enrollment.form.placeholder_deputy_directors'.tr(),
              emptyMessage: 'enrollment.form.empty_members'.tr(),
              enabled: !formState.isLoading && members.isNotEmpty,
              onChanged: (ids) => setState(() => _deputyDirectorIds = ids),
            ),

            const SizedBox(height: 20),

            // Secretario-Tesorero (condicional: si el club tiene ese rol)
            // Mutuamente exclusivo con Secretario + Tesorero individuales
            if (widget.hasSecretaryTreasurerRole) ...[
              // Toggle para elegir el modo
              _ToggleRow(
                icon: HugeIcons.strokeRoundedUserShield01,
                label: 'enrollment.form.label_use_secretary_treasurer'.tr(),
                subtitle:
                    'enrollment.form.subtitle_use_secretary_treasurer'.tr(),
                value: _secretaryTreasurerId != null,
                enabled: !formState.isLoading,
                onChanged: (v) => setState(() {
                  if (v) {
                    // Al activar: limpiar secretario y tesorero
                    _secretaryId = null;
                    _treasurerId = null;
                    // Mantener el ID si ya había uno
                    _secretaryTreasurerId ??= '';
                  } else {
                    _secretaryTreasurerId = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
            ],

            // Secretario y Tesorero: solo se muestran si NO se usa el cargo combinado
            if (!widget.hasSecretaryTreasurerRole ||
                _secretaryTreasurerId == null) ...[
              _FieldLabel(label: 'enrollment.form.label_secretary'.tr()),
              const SizedBox(height: 8),
              _SingleMemberSelector(
                selectedId: _secretaryId,
                members: members,
                placeholder: 'enrollment.form.placeholder_secretary'.tr(),
                emptyMessage: 'enrollment.form.empty_members'.tr(),
                enabled: !formState.isLoading && members.isNotEmpty,
                onChanged: (id) => setState(() => _secretaryId = id),
                onClear: () => setState(() => _secretaryId = null),
              ),

              const SizedBox(height: 20),

              _FieldLabel(label: 'enrollment.form.label_treasurer'.tr()),
              const SizedBox(height: 8),
              _SingleMemberSelector(
                selectedId: _treasurerId,
                members: members,
                placeholder: 'enrollment.form.placeholder_treasurer'.tr(),
                emptyMessage: 'enrollment.form.empty_members'.tr(),
                enabled: !formState.isLoading && members.isNotEmpty,
                onChanged: (id) => setState(() => _treasurerId = id),
                onClear: () => setState(() => _treasurerId = null),
              ),

              const SizedBox(height: 20),
            ],

            // Selector de Secretario-Tesorero (visible solo cuando está activo el toggle)
            if (widget.hasSecretaryTreasurerRole &&
                _secretaryTreasurerId != null) ...[
              _FieldLabel(label: 'enrollment.form.label_secretary_treasurer'.tr()),
              const SizedBox(height: 8),
              _SingleMemberSelector(
                selectedId: _secretaryTreasurerId!.isEmpty
                    ? null
                    : _secretaryTreasurerId,
                members: members,
                placeholder: 'enrollment.form.placeholder_secretary_treasurer'.tr(),
                emptyMessage: 'enrollment.form.empty_members'.tr(),
                enabled: !formState.isLoading && members.isNotEmpty,
                onChanged: (id) =>
                    setState(() => _secretaryTreasurerId = id),
                onClear: () =>
                    setState(() => _secretaryTreasurerId = ''),
              ),
              const SizedBox(height: 20),
            ],

            // ── Error ────────────────────────────────────────────────────
            if (formState.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlert02,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formState.errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
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
              text: _isEdit ? 'enrollment.form.button_save_changes'.tr() : 'enrollment.form.button_enroll'.tr(),
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
    );
  }

  InputDecoration _inputDecoration(
    SacColors c, {
    required String hintText,
    required HugeIconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: HugeIcon(
        icon: prefixIcon,
        color: c.textTertiary,
        size: 20,
      ),
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        HugeIcon(icon: icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
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

/// Etiqueta de campo con badge opcional.
class _FieldLabel extends StatelessWidget {
  final String label;
  final String? badge;

  const _FieldLabel({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasError
                ? AppColors.error
                : hasResult
                    ? AppColors.primary
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
                      ? AppColors.primary
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
                            fontSize: 14,
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
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      hasError
                          ? 'enrollment.form.location_error_hint'.tr()
                          : 'enrollment.form.location_hint'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: hasError ? AppColors.error : c.textTertiary,
                      ),
                    ),
            ),
            HugeIcon(
              icon: hasResult
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedArrowRight01,
              color: hasResult ? AppColors.primary : c.textTertiary,
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border, width: 1.5),
          ),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 13,
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre del día (tappable para deseleccionar)
          GestureDetector(
            onTap: enabled ? onTapDay : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          // Horario (tappable para cambiar la hora)
          GestureDetector(
            onTap: enabled ? onTapTime : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: AppColors.primary.withValues(alpha: 0.7),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time ?? '09:00',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.85),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: value ? AppColors.primary : c.textTertiary,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// Campo de solo lectura mostrando el nombre del director.
class _ReadOnlyMemberField extends StatelessWidget {
  final ClubMember? member;
  final String placeholder;

  const _ReadOnlyMemberField({
    this.member,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: c.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: member != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member!.fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                      ),
                      Text(
                        member!.clubRole ?? 'enrollment.form.role_director'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    placeholder,
                    style: TextStyle(fontSize: 14, color: c.textTertiary),
                  ),
          ),
          if (member != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'enrollment.form.badge_automatic'.tr(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selector de un único miembro con bottom sheet.
class _SingleMemberSelector extends StatelessWidget {
  final String? selectedId;
  final List<ClubMember> members;
  final String placeholder;
  final String emptyMessage;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onClear;

  const _SingleMemberSelector({
    this.selectedId,
    required this.members,
    required this.placeholder,
    required this.emptyMessage,
    required this.enabled,
    required this.onChanged,
    this.onClear,
  });

  ClubMember? get _selected =>
      selectedId != null
          ? members.where((m) => m.userId == selectedId).firstOrNull
          : null;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final selected = _selected;

    return GestureDetector(
      onTap: enabled && members.isNotEmpty
          ? () => _showMemberSheet(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected != null ? AppColors.primary : c.border,
            width: selected != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: selected != null
                  ? HugeIcons.strokeRoundedUserCheck01
                  : HugeIcons.strokeRoundedUserAdd01,
              color: selected != null ? AppColors.primary : c.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selected != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                        ),
                        if (selected.clubRole != null)
                          Text(
                            selected.clubRole!,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      members.isEmpty ? emptyMessage : placeholder,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textTertiary,
                      ),
                    ),
            ),
            if (selected != null && onClear != null)
              GestureDetector(
                onTap: enabled ? onClear : null,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  color: c.textTertiary,
                  size: 18,
                ),
              )
            else if (members.isNotEmpty)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  void _showMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberPickerSheet(
        members: members,
        selectedId: selectedId,
        multiSelect: false,
        onConfirm: (ids) {
          onChanged(ids.isNotEmpty ? ids.first : null);
        },
      ),
    );
  }
}

/// Selector de múltiples miembros con bottom sheet y límite.
class _MultiMemberSelector extends StatelessWidget {
  final List<String> selectedIds;
  final List<ClubMember> members;
  final int maxCount;
  final String placeholder;
  final String emptyMessage;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  const _MultiMemberSelector({
    required this.selectedIds,
    required this.members,
    required this.maxCount,
    required this.placeholder,
    required this.emptyMessage,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final selectedMembers =
        members.where((m) => selectedIds.contains(m.userId)).toList();

    return GestureDetector(
      onTap: enabled && members.isNotEmpty
          ? () => _showMemberSheet(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedMembers.isNotEmpty ? AppColors.primary : c.border,
            width: selectedMembers.isNotEmpty ? 1.5 : 1,
          ),
        ),
        child: selectedMembers.isEmpty
            ? Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserAdd01,
                    color: c.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    members.isEmpty ? emptyMessage : placeholder,
                    style: TextStyle(fontSize: 14, color: c.textTertiary),
                  ),
                  const Spacer(),
                  if (members.isNotEmpty)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: c.textTertiary,
                      size: 18,
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...selectedMembers.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'enrollment.form.tap_to_edit'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberPickerSheet(
        members: members,
        selectedId: selectedIds.isNotEmpty ? selectedIds.first : null,
        selectedIds: selectedIds,
        multiSelect: true,
        maxSelect: maxCount,
        onConfirm: (ids) => onChanged(ids),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de selección de miembros
// ─────────────────────────────────────────────────────────────────────────────

class _MemberPickerSheet extends StatefulWidget {
  final List<ClubMember> members;
  final String? selectedId;
  final List<String> selectedIds;
  final bool multiSelect;
  final int maxSelect;
  final ValueChanged<List<String>> onConfirm;

  const _MemberPickerSheet({
    required this.members,
    this.selectedId,
    this.selectedIds = const [],
    required this.multiSelect,
    this.maxSelect = 1,
    required this.onConfirm,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  late Set<String> _selected;
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    if (widget.multiSelect) {
      _selected = Set.from(widget.selectedIds);
    } else {
      _selected = widget.selectedId != null ? {widget.selectedId!} : {};
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClubMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return widget.members;
    final q = _searchQuery.toLowerCase();
    return widget.members
        .where((m) => m.fullName.toLowerCase().contains(q))
        .toList();
  }

  void _confirm() {
    Navigator.of(context).pop();
    widget.onConfirm(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final filtered = _filteredMembers;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.multiSelect
                          ? 'enrollment.picker.title_members'.tr()
                          : 'enrollment.picker.title_member'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    if (widget.multiSelect)
                      Text(
                        'enrollment.picker.selected_count'.tr(namedArgs: {
                          'current': '${_selected.length}',
                          'max': '${widget.maxSelect}',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: _confirm,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text('enrollment.picker.done'.tr()),
                ),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'enrollment.picker.search_hint'.tr(),
                prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: c.textTertiary,
                  size: 18,
                ),
                filled: true,
                fillColor: c.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Lista
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'enrollment.picker.no_results'.tr(),
                      style: TextStyle(color: c.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final member = filtered[i];
                      final isSelected = _selected.contains(member.userId);
                      final canSelect = isSelected ||
                          !widget.multiSelect ||
                          _selected.length < widget.maxSelect;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          radius: 18,
                          child: Text(
                            member.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          member.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: c.text,
                          ),
                        ),
                        subtitle: member.clubRole != null
                            ? Text(
                                member.clubRole!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: AppColors.primary,
                                size: 22,
                              )
                            : null,
                        enabled: canSelect,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () {
                          setState(() {
                            if (widget.multiSelect) {
                              if (isSelected) {
                                _selected.remove(member.userId);
                              } else if (canSelect) {
                                _selected.add(member.userId);
                              }
                            } else {
                              _selected = {member.userId};
                              // Para single select, confirmar de inmediato
                              Future.microtask(_confirm);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

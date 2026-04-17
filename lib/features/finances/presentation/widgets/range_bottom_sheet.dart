import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/transaction_filter.dart';

export '../../domain/entities/transaction_filter.dart' show DateRangePreset;

/// Bottom sheet for choosing a date range preset or a custom range.
///
/// Manages local state before the user taps "Aplicar".
class RangeBottomSheet extends StatefulWidget {
  final DateRangePreset currentPreset;
  final DateTime? currentStart;
  final DateTime? currentEnd;
  final void Function(
    DateRangePreset preset,
    DateTime? start,
    DateTime? end,
  ) onApply;

  const RangeBottomSheet({
    super.key,
    required this.currentPreset,
    this.currentStart,
    this.currentEnd,
    required this.onApply,
  });

  @override
  State<RangeBottomSheet> createState() => _RangeBottomSheetState();
}

class _RangeBottomSheetState extends State<RangeBottomSheet> {
  late DateRangePreset _selectedPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.currentPreset;
    _customStart = widget.currentStart;
    _customEnd = widget.currentEnd;
  }

  void _onPresetChanged(DateRangePreset? preset) {
    if (preset == null) return;
    setState(() => _selectedPreset = preset);
  }

  void _setCustomStart(DateTime date) =>
      setState(() => _customStart = date);

  void _setCustomEnd(DateTime date) =>
      setState(() => _customEnd = date);

  void _onApply() {
    widget.onApply(_selectedPreset, _customStart, _customEnd);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rango de fechas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.sac.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          RadioGroup<DateRangePreset>(
            groupValue: _selectedPreset,
            onChanged: _onPresetChanged,
            child: Column(
              children: [
                _RangeOption(
                  preset: DateRangePreset.thisMonth,
                  label: 'Este mes',
                ),
                _RangeOption(
                  preset: DateRangePreset.last3Months,
                  label: 'Últimos 3 meses',
                ),
                _RangeOption(
                  preset: DateRangePreset.lastYear,
                  label: 'Último año',
                ),
                _RangeOption(
                  preset: DateRangePreset.custom,
                  label: 'Rango personalizado',
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _selectedPreset == DateRangePreset.custom
                ? _CustomDateFields(
                    startDate: _customStart,
                    endDate: _customEnd,
                    onStartChanged: _setCustomStart,
                    onEndChanged: _setCustomEnd,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          _BottomSheetApplyButton(onApply: _onApply),
        ],
      ),
    );
  }
}

// ── Range option row ───────────────────────────────────────────────────────────

class _RangeOption extends StatelessWidget {
  final DateRangePreset preset;
  final String label;

  const _RangeOption({
    required this.preset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Radio<DateRangePreset>(
            value: preset,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.sac.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom date field row ──────────────────────────────────────────────────────

class _CustomDateFields extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;

  const _CustomDateFields({
    required this.startDate,
    required this.endDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime? initial,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: _DateField(
              label: 'Desde',
              date: startDate,
              onTap: () => _pickDate(
                context,
                initial: startDate,
                onChanged: onStartChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DateField(
              label: 'Hasta',
              date: endDate,
              onTap: () => _pickDate(
                context,
                initial: endDate,
                onChanged: onEndChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = date != null
        ? DateFormat('d MMM yy', 'es').format(date!)
        : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.sac.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.sac.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatted,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.sac.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared bottom sheet chrome ─────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.sac.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _BottomSheetApplyButton extends StatelessWidget {
  final VoidCallback onApply;

  const _BottomSheetApplyButton({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onApply,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Aplicar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../views/location_picker_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Selector de hora estilo Cupertino en bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Abre un bottom sheet con dos ruedas CupertinoPicker (horas 00-23, minutos
/// 00-59) pre-seleccionadas en [initialTime].
///
/// Retorna el [TimeOfDay] confirmado o `null` si el usuario cierra sin
/// confirmar.
Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context,
  TimeOfDay initialTime,
) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimePickerSheet(initialTime: initialTime),
  );
}

/// Bottom sheet interna con los dos wheels de hora y minuto.
class _TimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;

  const _TimePickerSheet({required this.initialTime});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour;
  late int _minute;

  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
          ),

          // Header — título y botón Listo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'activities.widgets.time_picker_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                TextButton(
                  onPressed: _confirm,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Text('activities.widgets.time_picker_done'.tr()),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: c.border),

          // Wheels
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Highlight band — resalta el item seleccionado
                Positioned(
                  top: 88,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Wheel de horas
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _hourController,
                        itemExtent: 44,
                        looping: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (index) {
                          _hour = index % 24;
                        },
                        children: List.generate(24, (i) {
                          return Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Separador de dos puntos
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),

                    // Wheel de minutos
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _minuteController,
                        itemExtent: 44,
                        looping: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (index) {
                          _minute = index % 60;
                        },
                        children: List.generate(60, (i) {
                          return Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Espacio para el safe-area inferior
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabecera de sección
// ─────────────────────────────────────────────────────────────────────────────

/// Cabecera de sección con icono y label, usada en create y edit activity.
class ActivitySectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String label;

  const ActivitySectionHeader({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: HugeIcon(icon: icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.divider, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo tappable genérico (picker de catálogo)
// ─────────────────────────────────────────────────────────────────────────────

/// Campo de formulario tappable que abre un bottom sheet picker.
class ActivityPickerField extends StatelessWidget {
  final String label;
  final String hint;
  final HugeIconData icon;
  final String? selectedName;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;

  const ActivityPickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.selectedName,
    this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasValue = selectedName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: (enabled && !isLoading) ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: hasValue
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : c.border,
                width: hasValue ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 20,
                  color: hasValue ? AppColors.primary : c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          hasValue ? selectedName! : hint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: hasValue ? c.text : c.textTertiary,
                          ),
                        ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: enabled ? c.textSecondary : c.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo tappable de selección de ubicación
// ─────────────────────────────────────────────────────────────────────────────

/// Campo que muestra la ubicación seleccionada o un placeholder,
/// y abre [LocationPickerView] al ser pulsado.
class ActivityLocationPickerField extends StatelessWidget {
  final LocationPickerResult? result;
  final bool hasError;
  final bool enabled;
  final VoidCallback? onTap;

  const ActivityLocationPickerField({
    super.key,
    required this.result,
    required this.hasError,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasResult = result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'activities.widgets.location_label'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: hasError
                  ? Border.all(color: theme.colorScheme.error, width: 1.5)
                  : hasResult
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: HugeIcon(
                    icon: hasResult
                        ? HugeIcons.strokeRoundedLocation01
                        : HugeIcons.strokeRoundedLocation03,
                    size: 20,
                    color: hasResult ? AppColors.primary : c.textSecondary,
                  ),
                ),
                Expanded(
                  child: hasResult
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result!.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.text,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${result!.lat.toStringAsFixed(5)}, ${result!.long.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textTertiary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'activities.widgets.location_hint'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textTertiary,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              'activities.widgets.location_error'.tr(),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo de selección de fecha
// ─────────────────────────────────────────────────────────────────────────────

/// Campo tappable para seleccionar una fecha.
class ActivityDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const ActivityDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasValue = value != null;
    final formatted = hasValue
        ? DateFormat('d MMM yyyy', 'es').format(value!.toLocal())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surfaceVariant,
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  offset: const Offset(0, 3),
                  blurRadius: 20,
                ),
              ],
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: hasValue
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  size: 20,
                  color: hasValue ? AppColors.primary : c.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatted ?? 'activities.widgets.date_hint'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          hasValue ? FontWeight.w500 : FontWeight.normal,
                      color: hasValue ? c.text : c.textTertiary,
                    ),
                  ),
                ),
                if (hasValue && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: c.textSecondary,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: c.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector segmentado (Presencial / Virtual)
// ─────────────────────────────────────────────────────────────────────────────

/// Opción individual del [ActivitySegmentedSelector].
class ActivitySegmentOption<T> {
  final T value;
  final String label;

  const ActivitySegmentOption({required this.value, required this.label});
}

/// Selector segmentado tipo toggle-chip horizontal.
class ActivitySegmentedSelector<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<ActivitySegmentOption<T>> options;
  final void Function(T)? onChanged;

  const ActivitySegmentedSelector({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = opt.value == value;
            return Expanded(
              child: GestureDetector(
                onTap: onChanged != null ? () => onChanged!(opt.value) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : c.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.sac.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : c.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de selección y previsualización de imagen
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra un picker de imagen (galería/cámara) con vista previa.
///
/// Si [networkImageUrl] no es null y no se ha seleccionado un archivo local,
/// muestra la imagen actual de la actividad como vista previa.
class ActivityImagePicker extends StatelessWidget {
  final String? localImagePath;
  final String? networkImageUrl;
  final bool isUploading;
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const ActivityImagePicker({
    super.key,
    required this.localImagePath,
    this.networkImageUrl,
    required this.isUploading,
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final hasLocalImage = localImagePath != null;
    final hasNetworkImage = networkImageUrl != null && networkImageUrl!.isNotEmpty;
    final hasAnyImage = hasLocalImage || hasNetworkImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'activities.widgets.image_label'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            color: enabled ? c.surface : c.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: hasAnyImage
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : c.border,
              width: hasAnyImage ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                offset: const Offset(0, 3),
                blurRadius: 20,
              ),
            ],
          ),
          child: isUploading
              ? _ActivityUploadingBody()
              : hasLocalImage
                  ? _ActivityPreviewBody(
                      imageProvider: FileImage(File(localImagePath!)),
                      enabled: enabled,
                      onPickGallery: onPickGallery,
                      onPickCamera: onPickCamera,
                    )
                  : hasNetworkImage
                      ? _ActivityPreviewBody(
                          imageProvider: NetworkImage(networkImageUrl!),
                          enabled: enabled,
                          onPickGallery: onPickGallery,
                          onPickCamera: onPickCamera,
                        )
                      : _ActivityPickerBody(
                          enabled: enabled,
                          onPickGallery: onPickGallery,
                          onPickCamera: onPickCamera,
                        ),
        ),
      ],
    );
  }
}

class _ActivityUploadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
          ),
          const SizedBox(height: 10),
          Text(
            'activities.widgets.image_uploading'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPickerBody extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _ActivityPickerBody({
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _ActivityImageSourceButton(
              icon: HugeIcons.strokeRoundedImage01,
              label: 'activities.widgets.gallery'.tr(),
              enabled: enabled,
              onTap: onPickGallery,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActivityImageSourceButton(
              icon: HugeIcons.strokeRoundedCamera01,
              label: 'activities.widgets.camera'.tr(),
              enabled: enabled,
              onTap: onPickCamera,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityImageSourceButton extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActivityImageSourceButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 24,
              color: AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPreviewBody extends StatelessWidget {
  final ImageProvider imageProvider;
  final bool enabled;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _ActivityPreviewBody({
    required this.imageProvider,
    required this.enabled,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: imageProvider,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppColors.primaryLight,
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedImage01,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              if (enabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ActivityRepickMenu(
                    onPickGallery: onPickGallery,
                    onPickCamera: onPickCamera,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'activities.widgets.image_loaded'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityRepickMenu extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _ActivityRepickMenu({
    required this.onPickGallery,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'gallery') onPickGallery();
        if (value == 'camera') onPickCamera();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'gallery',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('activities.widgets.gallery'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'camera',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('activities.widgets.camera'.tr()),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedEdit02,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

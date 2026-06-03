import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Tipos de sangre soportados por el backend (`enum blood_type` en Prisma).
///
/// - [display] es el valor visible al usuario (`'A+'`, `'O-'`, etc.).
/// - [apiKey] es la key TypeScript del enum que el backend espera en PATCH
///   `/users/:id` con campo `blood` (validado por `@IsEnum(blood_type)`).
///
/// El backend puede devolver cualquiera de los dos formatos según el endpoint
/// o la mutación (`'O+'` o `'O_POSITIVE'`). La UI SIEMPRE debe mostrar
/// [display], nunca la key de base/API.
enum BloodType {
  aPos('A+', 'A_POSITIVE'),
  aNeg('A-', 'A_NEGATIVE'),
  bPos('B+', 'B_POSITIVE'),
  bNeg('B-', 'B_NEGATIVE'),
  abPos('AB+', 'AB_POSITIVE'),
  abNeg('AB-', 'AB_NEGATIVE'),
  oPos('O+', 'O_POSITIVE'),
  oNeg('O-', 'O_NEGATIVE');

  const BloodType(this.display, this.apiKey);

  final String display;
  final String apiKey;

  static BloodType? fromDisplay(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toUpperCase();
    for (final t in BloodType.values) {
      if (t.display.toUpperCase() == normalized ||
          t.apiKey.toUpperCase() == normalized) {
        return t;
      }
    }
    return null;
  }

  static String? displayFor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return fromDisplay(value)?.display ?? value.trim();
  }
}

/// Bottomsheet para elegir tipo de sangre.
///
/// Devuelve el [BloodType] seleccionado, o `null` si el usuario cancela.
Future<BloodType?> showBloodTypeSelector(
  BuildContext context, {
  BloodType? current,
}) {
  return showModalBottomSheet<BloodType>(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    builder: (ctx) => _BloodTypeSheet(current: current),
  );
}

class _BloodTypeSheet extends StatelessWidget {
  const _BloodTypeSheet({this.current});

  final BloodType? current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile.medical_info.blood_type_select_title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'profile.medical_info.blood_type_select_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: BloodType.values.map((t) {
                final selected = current == t;
                return _BloodChip(
                  label: t.display,
                  selected: selected,
                  onTap: () => Navigator.of(context).pop(t),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloodChip extends StatelessWidget {
  const _BloodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: selected ? scheme.onPrimary : scheme.onSurface,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

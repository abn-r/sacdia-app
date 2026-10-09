import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';

/// Fila de persona de las pantallas de investidura: casilla opcional, avatar
/// con iniciales (color de su clase), nombre, detalle y contenido extra.
///
/// Si [selected] no es nulo, toda la fila alterna la selección (objetivo táctil
/// completo) y se anuncia como casilla a los lectores de pantalla.
class InvestiturePersonRow extends StatelessWidget {
  const InvestiturePersonRow({
    super.key,
    required this.name,
    this.className,
    this.detail,
    this.selected,
    this.onSelectedChanged,
    this.selectSemanticLabel,
    this.trailing,
    this.footer,
  });

  final String name;
  final String? className;
  final String? detail;

  /// `null` = fila sin selección (solo lectura).
  final bool? selected;
  final ValueChanged<bool>? onSelectedChanged;
  final String? selectSemanticLabel;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final classColor = AppColors.classColor(className ?? '');
    final selectable = selected != null && onSelectedChanged != null;
    final isSelected = selected ?? false;

    final content = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? classColor.withValues(alpha: 0.6) : c.ink150,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (selectable) ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) => onSelectedChanged!(value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: classColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              CircleAvatar(
                radius: 22,
                backgroundColor: classColor.withValues(alpha: 0.12),
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: classColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.ink900,
                          ),
                    ),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.ink500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );

    final card = Material(
      color: c.paper,
      borderRadius: BorderRadius.circular(18),
      child: selectable
          ? SacInkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelectedChanged!(!isSelected),
              child: content,
            )
          : content,
    );

    if (!selectable || selectSemanticLabel == null) return card;
    return Semantics(
      label: selectSemanticLabel,
      checked: isSelected,
      child: card,
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
  }
}

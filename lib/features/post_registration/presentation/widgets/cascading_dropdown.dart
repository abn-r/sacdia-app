import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

/// Widget genérico para dropdown en cascada
class CascadingDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? selectedValue;
  final void Function(T?)? onChanged;
  final bool isLoading;
  final bool isEnabled;
  final String Function(T) getItemLabel;
  final dynamic Function(T) getItemValue;
  final String? hintText;

  const CascadingDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.getItemLabel,
    required this.getItemValue,
    this.isLoading = false,
    this.isEnabled = true,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
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
        if (isLoading)
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: context.sac.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: SacLoadingSmall(),
              ),
            ),
          )
        else
          DropdownButtonFormField<dynamic>(
            value: selectedValue != null ? getItemValue(selectedValue as T) : null,
            decoration: InputDecoration(
              hintText: hintText ??
                  'post_registration.dropdown.select_label'
                      .tr(namedArgs: {'label': label}),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: items.isEmpty
                ? null
                : items.map((item) {
                    return DropdownMenuItem<dynamic>(
                      value: getItemValue(item),
                      child: Text(getItemLabel(item)),
                    );
                  }).toList(),
            onChanged: isEnabled
                ? (value) {
                    if (value != null && onChanged != null) {
                      final selectedItem = items.firstWhere(
                        (item) => getItemValue(item) == value,
                      );
                      onChanged!(selectedItem);
                    }
                  }
                : null,
            isExpanded: true,
          ),
      ],
    );
  }
}

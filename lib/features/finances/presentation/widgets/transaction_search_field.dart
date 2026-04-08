import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';

/// Debounced search field for the All Transactions screen.
///
/// Fires [onSearch] after 300 ms of idle typing.  Fires immediately when the
/// clear button is tapped.
class TransactionSearchField extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String initialValue;

  const TransactionSearchField({
    super.key,
    required this.onSearch,
    this.initialValue = '',
  });

  @override
  State<TransactionSearchField> createState() => _TransactionSearchFieldState();
}

class _TransactionSearchFieldState extends State<TransactionSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value);
    });
    // Rebuild so the clear icon appears/disappears.
    setState(() {});
  }

  void _onClear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onSearch('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF252525) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 18,
              color: context.sac.textTertiary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.sac.text,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, categoría, monto\u2026',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: context.sac.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 18,
                color: context.sac.textTertiary,
              ),
              onPressed: _onClear,
            ),
        ],
      ),
    );
  }
}

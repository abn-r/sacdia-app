import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de entrada de precio en MXN.
///
/// Internamente almacena centavos (enteros) pero muestra pesos con dos
/// decimales: "$XX.XX". El valor de centavos se expone vía [onChanged].
///
/// Ejemplo de uso:
/// ```dart
/// PriceInput(
///   label: 'Monto pagado',
///   onChanged: (centavos) => setState(() => _monto = centavos),
/// )
/// ```
class PriceInput extends StatefulWidget {
  final String label;
  final String? hint;
  final int? initialCentavos;
  final ValueChanged<int>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextEditingController? controller;

  const PriceInput({
    super.key,
    required this.label,
    this.hint,
    this.initialCentavos,
    this.onChanged,
    this.validator,
    this.controller,
  });

  @override
  State<PriceInput> createState() => _PriceInputState();
}

class _PriceInputState extends State<PriceInput> {
  late final TextEditingController _controller;
  bool _isExternal = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _isExternal = true;
    } else {
      _controller = TextEditingController();
    }
    if (widget.initialCentavos != null && widget.initialCentavos! > 0) {
      final pesos = widget.initialCentavos! ~/ 100;
      final cents = widget.initialCentavos!.remainder(100).abs();
      _controller.text = '$pesos.${cents.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    if (!_isExternal) _controller.dispose();
    super.dispose();
  }

  /// Parsea el texto ingresado como pesos decimales y devuelve centavos.
  int _parseAsCentavos(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d.]'), '');
    if (clean.isEmpty) return 0;
    final amount = double.tryParse(clean) ?? 0.0;
    return (amount * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '0.00',
        prefixText: '\$ ',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Allow digits and at most one decimal point
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        // Max two decimal places — enforced by custom formatter
        _TwoDecimalInputFormatter(),
      ],
      validator: widget.validator ??
          (value) {
            final centavos = _parseAsCentavos(value ?? '');
            if (centavos <= 0) return 'Ingresá un monto mayor a \$0.00';
            return null;
          },
      onChanged: (value) {
        final centavos = _parseAsCentavos(value);
        widget.onChanged?.call(centavos);
      },
    );
  }
}

/// Formateador que limita la entrada a dos decimales.
class _TwoDecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Allow backspace/delete through
    if (text.isEmpty) return newValue;

    // Block multiple decimal points
    final dotCount = text.split('.').length - 1;
    if (dotCount > 1) return oldValue;

    // Limit to 2 decimal places
    final parts = text.split('.');
    if (parts.length == 2 && parts[1].length > 2) return oldValue;

    return newValue;
  }
}

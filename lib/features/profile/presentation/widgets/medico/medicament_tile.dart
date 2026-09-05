import 'package:flutter/material.dart';
import 'package:sacdia_app/features/post_registration/data/models/medicine_model.dart';
import 'medico_tokens.dart';

/// Fila para un medicamento — nombre destacado + dosis abajo (si tiene).
/// Fondo mint suave para diferenciarlo visualmente del resto.
class MedicamentTile extends StatelessWidget {
  final MedicineModel medicine;

  const MedicamentTile({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    final m = MedicoTokens.of(context);
    return Material(
      color: m.mintSoft,
      borderRadius: BorderRadius.circular(MedicoTokens.rChipSmall),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: m.mintInk,
                      fontSize: 14,
                    ),
                  ),
                  if (medicine.dose != null && medicine.dose!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      medicine.dose!,
                      style: TextStyle(
                        fontSize: 12,
                        color: m.mintInkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

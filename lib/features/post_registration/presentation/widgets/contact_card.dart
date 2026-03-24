import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../data/models/emergency_contact_model.dart';

/// Card que muestra un contacto de emergencia con opciones de edición y eliminación
class ContactCard extends StatelessWidget {
  final EmergencyContactModel contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactCard({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          children: [
            // Icono de contacto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedUser,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Información del contacto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (contact.relationshipTypeName != null) ...[
                    Text(
                      contact.relationshipTypeName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.sac.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCall,
                        size: 16,
                        color: context.sac.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        contact.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.sac.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Botones de acción
            Column(
              children: [
                IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 20),
                  color: Theme.of(context).primaryColor,
                  onPressed: onEdit,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon:
                      HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 20),
                  color: AppColors.error,
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

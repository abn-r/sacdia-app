import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/contact_card.dart';
import 'add_edit_contact_view.dart';

/// Vista para gestionar contactos de emergencia
class EmergencyContactsView extends ConsumerWidget {
  const EmergencyContactsView({super.key});

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    int contactId,
    String contactName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Eliminar Contacto',
      content: '¿Estás seguro de que deseas eliminar a $contactName?',
      confirmLabel: 'Eliminar',
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(emergencyContactsProvider.notifier)
            .deleteContact(contactId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Contacto eliminado correctamente'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${e.toString()}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddEdit(BuildContext context,
      {dynamic contact}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditContactView(contact: contact),
      ),
    );

    if (result == true && context.mounted) {
      // Opcionalmente cerrar esta vista también si estamos en un bottom sheet
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos de Emergencia'),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () {
              ref.read(emergencyContactsProvider.notifier).refresh();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: const Text('Reintentar'),
                onPressed: () {
                  ref.read(emergencyContactsProvider.notifier).refresh();
                },
              ),
            ],
          ),
        ),
        data: (contacts) {
          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedContactBook,
                    size: 64,
                    color: AppColors.lightTextTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay contactos de emergencia',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega al menos un contacto de emergencia',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon:
                        HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 20),
                    label: const Text('Agregar Contacto'),
                    onPressed: () => _navigateToAddEdit(context),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Información sobre límite
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: contacts.length >= 5
                    ? AppColors.accentLight
                    : AppColors.primaryLight,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: contacts.length >= 5
                          ? HugeIcons.strokeRoundedAlertCircle
                          : HugeIcons.strokeRoundedInformationCircle,
                      color: contacts.length >= 5
                          ? AppColors.accentDark
                          : AppColors.primaryDark,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        contacts.length >= 5
                            ? 'Has alcanzado el límite de 5 contactos'
                            : 'Puedes agregar hasta 5 contactos (${contacts.length}/5)',
                        style: TextStyle(
                          fontSize: 14,
                          color: contacts.length >= 5
                              ? AppColors.accentDark
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de contactos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ContactCard(
                      contact: contact,
                      onEdit: () =>
                          _navigateToAddEdit(context, contact: contact),
                      onDelete: () => _showDeleteConfirmation(
                        context,
                        ref,
                        contact.id!,
                        contact.name,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: contactsAsync.maybeWhen(
        data: (contacts) {
          // Solo mostrar cuando ya existan contactos y no se haya alcanzado el límite
          if (contacts.isEmpty || contacts.length >= 5) return null;
          return FloatingActionButton.extended(
            onPressed: () => _navigateToAddEdit(context),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 22,
              color: Colors.white,
            ),
            label: const Text(
              'Agregar Contacto',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Contacto'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a $contactName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(emergencyContactsProvider.notifier).deleteContact(contactId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacto eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddEdit(BuildContext context, {dynamic contact}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditContactView(contact: contact),
      ),
    );

    // Si se guardó correctamente, la vista ya cerró
    if (result == true && context.mounted) {
      // Opcionalmente cerrar esta vista también si estamos en un bottom sheet
      // Navigator.of(context).pop();
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(emergencyContactsProvider.notifier).refresh();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
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
                  Icon(
                    Icons.contacts_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay contactos de emergencia',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega al menos un contacto de emergencia',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
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
                color: contacts.length >= 5 ? Colors.orange.shade50 : Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(
                      contacts.length >= 5 ? Icons.warning_amber : Icons.info_outline,
                      color: contacts.length >= 5 ? Colors.orange : Colors.blue,
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
                              ? Colors.orange.shade900
                              : Colors.blue.shade900,
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
                      onEdit: () => _navigateToAddEdit(context, contact: contact),
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
          if (contacts.length >= 5) return null;
          return FloatingActionButton.extended(
            onPressed: () => _navigateToAddEdit(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Contacto'),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

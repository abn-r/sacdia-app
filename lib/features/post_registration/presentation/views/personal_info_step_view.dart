import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/personal_info_providers.dart';
import 'emergency_contacts_view.dart';
import 'legal_representative_view.dart';
import 'allergies_selection_view.dart';
import 'diseases_selection_view.dart';

/// Vista del paso 2: Información Personal
class PersonalInfoStepView extends ConsumerStatefulWidget {
  const PersonalInfoStepView({super.key});

  @override
  ConsumerState<PersonalInfoStepView> createState() => _PersonalInfoStepViewState();
}

class _PersonalInfoStepViewState extends ConsumerState<PersonalInfoStepView> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(personalInfoFormProvider);
    final contactsAsync = ref.watch(emergencyContactsProvider);
    final legalRepAsync = ref.watch(legalRepresentativeProvider);
    final requiresLegalRepAsync = ref.watch(legalRepresentativeRequiredProvider);
    final selectedAllergies = ref.watch(selectedAllergiesProvider);
    final selectedDiseases = ref.watch(selectedDiseasesProvider);
    final canComplete = ref.watch(canCompleteStep2Provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información Personal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título de sección
            const Text(
              'Datos Personales',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Género
            DropdownButtonFormField<String>(
              value: formState.gender,
              decoration: const InputDecoration(
                labelText: 'Género *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
              ],
              onChanged: (value) {
                ref.read(personalInfoFormProvider.notifier).state =
                    formState.copyWith(gender: value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecciona tu género';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Fecha de nacimiento
            InkWell(
              onTap: () => _selectBirthdate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de Nacimiento *',
                  prefixIcon: Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  formState.birthdate != null
                      ? DateFormat('dd/MM/yyyy').format(formState.birthdate!)
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    color: formState.birthdate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bautizado
            SwitchListTile(
              title: const Text('¿Estás bautizado?'),
              value: formState.baptized,
              onChanged: (value) {
                ref.read(personalInfoFormProvider.notifier).state = formState.copyWith(
                  baptized: value,
                  baptismDate: value ? formState.baptismDate : null,
                );
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Fecha de bautismo (condicional)
            if (formState.baptized) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectBaptismDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Bautismo *',
                    prefixIcon: Icon(Icons.water_drop_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    formState.baptismDate != null
                        ? DateFormat('dd/MM/yyyy').format(formState.baptismDate!)
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: formState.baptismDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Sección de contactos de emergencia
            const Text(
              'Contactos de Emergencia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra al menos un contacto de emergencia',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
              data: (contacts) => _buildContactsSection(contacts),
            ),

            const SizedBox(height: 32),

            // Sección de representante legal (condicional)
            requiresLegalRepAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (required) {
                if (!required) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Representante Legal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Eres menor de 18 años, necesitas registrar un representante legal.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    legalRepAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Text('Error: $error'),
                      data: (rep) => _buildLegalRepSection(rep),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // Sección de alergias
            const Text(
              'Alergias',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              icon: Icons.healing_outlined,
              title: selectedAllergies.isEmpty
                  ? 'No hay alergias registradas'
                  : '${selectedAllergies.length} alergia(s) seleccionada(s)',
              buttonText: 'Seleccionar Alergias',
              onTap: () => _navigateToAllergiesSelection(),
              color: Colors.red,
            ),

            const SizedBox(height: 24),

            // Sección de enfermedades
            const Text(
              'Enfermedades',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSelectionCard(
              icon: Icons.medical_services_outlined,
              title: selectedDiseases.isEmpty
                  ? 'No hay enfermedades registradas'
                  : '${selectedDiseases.length} enfermedad(es) seleccionada(s)',
              buttonText: 'Seleccionar Enfermedades',
              onTap: () => _navigateToDiseasesSelection(),
              color: Colors.orange,
            ),

            const SizedBox(height: 32),

            // Botón de completar
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canComplete && !_isLoading ? _handleComplete : null,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Completar Paso 2'),
              ),
            ),

            const SizedBox(height: 16),

            // Mensaje si no puede completar
            if (!canComplete)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Completa todos los campos requeridos para continuar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection(List<dynamic> contacts) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(
          Icons.contacts_outlined,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          contacts.isEmpty
              ? 'No hay contactos registrados'
              : '${contacts.length} contacto(s) registrado(s)',
        ),
        subtitle: contacts.isEmpty
            ? const Text('Requerido: Al menos 1 contacto')
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToEmergencyContacts(),
      ),
    );
  }

  Widget _buildLegalRepSection(dynamic rep) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(
          Icons.family_restroom,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          rep != null ? rep.fullName : 'No hay representante registrado',
        ),
        subtitle: rep != null ? Text(rep.type.toUpperCase()) : const Text('Requerido'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToLegalRepresentative(),
      ),
    );
  }

  Widget _buildSelectionCard({
    required IconData icon,
    required String title,
    required String buttonText,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 99, now.month, now.day);
    final maxDate = DateTime(now.year - 3, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(personalInfoFormProvider).birthdate ?? maxDate,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      ref.read(personalInfoFormProvider.notifier).state =
          ref.read(personalInfoFormProvider).copyWith(birthdate: picked);
    }
  }

  Future<void> _selectBaptismDate(BuildContext context) async {
    final birthdate = ref.read(personalInfoFormProvider).birthdate;
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(personalInfoFormProvider).baptismDate ?? now,
      firstDate: birthdate ?? DateTime(1900),
      lastDate: now,
      helpText: 'Selecciona tu fecha de bautismo',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked != null) {
      ref.read(personalInfoFormProvider.notifier).state =
          ref.read(personalInfoFormProvider).copyWith(baptismDate: picked);
    }
  }

  Future<void> _navigateToEmergencyContacts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EmergencyContactsView(),
      ),
    );
  }

  Future<void> _navigateToLegalRepresentative() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LegalRepresentativeView(),
      ),
    );
  }

  Future<void> _navigateToAllergiesSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllergiesSelectionView(),
      ),
    );
  }

  Future<void> _navigateToDiseasesSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DiseasesSelectionView(),
      ),
    );
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final saveFunction = ref.read(savePersonalInfoProvider);
      await saveFunction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paso 2 completado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Navegar al siguiente paso o volver
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

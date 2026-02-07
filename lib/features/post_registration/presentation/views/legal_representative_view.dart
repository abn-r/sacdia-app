import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/legal_representative_model.dart';
import '../providers/personal_info_providers.dart';

/// Vista para gestionar el representante legal
class LegalRepresentativeView extends ConsumerStatefulWidget {
  const LegalRepresentativeView({super.key});

  @override
  ConsumerState<LegalRepresentativeView> createState() =>
      _LegalRepresentativeViewState();
}

class _LegalRepresentativeViewState extends ConsumerState<LegalRepresentativeView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _paternalSurnameController = TextEditingController();
  final _maternalSurnameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedType = 'padre';
  bool _isLoading = false;

  final List<Map<String, String>> _representativeTypes = [
    {'value': 'padre', 'label': 'Padre'},
    {'value': 'madre', 'label': 'Madre'},
    {'value': 'tutor', 'label': 'Tutor/Tutora'},
  ];

  @override
  void initState() {
    super.initState();
    // Cargar datos existentes si hay
    Future.microtask(() {
      final repAsync = ref.read(legalRepresentativeProvider);
      repAsync.whenData((rep) {
        if (rep != null && mounted) {
          setState(() {
            _nameController.text = rep.name;
            _paternalSurnameController.text = rep.paternalSurname;
            _maternalSurnameController.text = rep.maternalSurname;
            _phoneController.text = rep.phone;
            _selectedType = rep.type;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paternalSurnameController.dispose();
    _maternalSurnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final representative = LegalRepresentativeModel(
        name: _nameController.text.trim(),
        paternalSurname: _paternalSurnameController.text.trim(),
        maternalSurname: _maternalSurnameController.text.trim(),
        phone: _phoneController.text.trim(),
        type: _selectedType,
      );

      await ref.read(legalRepresentativeProvider.notifier).saveRepresentative(representative);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Representante legal guardado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Representante Legal'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _handleSave,
              tooltip: 'Guardar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nota informativa
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los menores de 18 años requieren un representante legal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tipo de representante
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo de representante *',
                prefixIcon: Icon(Icons.people_outline),
                border: OutlineInputBorder(),
              ),
              items: _representativeTypes.map((type) {
                return DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre(s) *',
                hintText: 'Ej: Juan Carlos',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El nombre debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Apellido Paterno
            TextFormField(
              controller: _paternalSurnameController,
              decoration: const InputDecoration(
                labelText: 'Apellido Paterno *',
                hintText: 'Ej: Pérez',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El apellido paterno es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El apellido debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Apellido Materno
            TextFormField(
              controller: _maternalSurnameController,
              decoration: const InputDecoration(
                labelText: 'Apellido Materno *',
                hintText: 'Ej: González',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El apellido materno es requerido';
                }
                if (value.trim().length < 2) {
                  return 'El apellido debe tener al menos 2 caracteres';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Teléfono
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                hintText: 'Ej: 5512345678',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El teléfono es requerido';
                }
                final phoneRegex = RegExp(r'^\d{10}$');
                if (!phoneRegex.hasMatch(value.trim())) {
                  return 'Ingresa un teléfono válido de 10 dígitos';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),

            // Botón de guardar
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar Representante Legal'),
                onPressed: _isLoading ? null : _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

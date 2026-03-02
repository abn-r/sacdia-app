import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

// ─── Colores mock ─────────────────────────────────────────────────────────────
const Color _sacRed = Color(0xFFCC0000);
const Color _sacBlack = Color(0xFF1A1A1A);
const Color _sacGrey = Color(0xFF9E9E9E);
const Color _sacBlue = Color(0xFF1565C0);

// ─── Datos mock ───────────────────────────────────────────────────────────────

class _MockAllergy {
  final int id;
  final String name;
  const _MockAllergy(this.id, this.name);
}

class _MockDisease {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  const _MockDisease(this.id, this.name, {this.description, required this.createdAt});
}

class _MockContact {
  final int id;
  final String name;
  final String phone;
  final String relationship;
  const _MockContact(this.id, this.name, this.phone, this.relationship);
}

final _mockAllergies = <_MockAllergy>[
  const _MockAllergy(1, 'Polen'),
  const _MockAllergy(2, 'Mariscos'),
  const _MockAllergy(3, 'Penicilina'),
];

final _mockDiseases = <_MockDisease>[
  _MockDisease(1, 'Asma', description: 'Leve, controlada con inhalador', createdAt: DateTime(2023, 3, 10)),
  _MockDisease(2, 'Diabetes Tipo 1', createdAt: DateTime(2022, 8, 5)),
];

final _mockContacts = <_MockContact>[
  const _MockContact(1, 'María López García', '50212345678', 'Madre'),
  const _MockContact(2, 'Roberto Méndez', '50298765432', 'Padre'),
];

const _relationshipTypes = ['Madre', 'Padre', 'Hermano/a', 'Tío/a', 'Abuelo/a', 'Tutor Legal', 'Otro'];

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL: Información Personal
// ═════════════════════════════════════════════════════════════════════════════

class MockPersonalInfoScreen extends StatelessWidget {
  const MockPersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sacRed,
      appBar: AppBar(
        backgroundColor: _sacRed,
        title: const Text(
          'INFORMACIÓN PERSONAL',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header con foto y nombre ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Color(0xFFE0E0E0),
                        child: Icon(Icons.person, size: 45, color: _sacGrey),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carlos Andrés Méndez López',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.email, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'carlos.mendez@correo.com',
                                style: TextStyle(fontSize: 14, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Contenido principal ───────────────────────────────────────
              Container(
                decoration: const BoxDecoration(color: Colors.white),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información básica
                    _buildSectionTitle('Información Básica', Icons.person),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.transgender,
                            title: 'Género',
                            value: 'Masculino',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.cake,
                            title: 'Fecha de Nacimiento',
                            value: '15/04/2008',
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.bloodtype,
                            title: 'Tipo de Sangre',
                            value: 'O+',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.church,
                            title: 'Bautizado',
                            value: 'Sí',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Información del club
                    _buildSectionTitle('Información del Club', Icons.groups),
                    _buildInfoCard(
                      icon: Icons.people,
                      title: 'Club',
                      value: 'Club Renacer Guatemala',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.work,
                            title: 'Rol',
                            value: 'Explorador',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.school,
                            title: 'Clase',
                            value: 'Orientador Avanzado',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Información médica
                    _buildSectionTitle('Información Médica', Icons.medical_services),

                    // Enfermedades → navega a MockDiseasesScreen
                    _buildInfoCard(
                      icon: Icons.medical_information,
                      title: 'Enfermedades',
                      value: '${_mockDiseases.length} enfermedades activas',
                      isEditable: true,
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MockDiseasesScreen()),
                      ),
                    ),

                    _buildInfoCard(
                      icon: Icons.health_and_safety,
                      title: 'Medicamentos',
                      value: 'Ninguno registrado',
                      isEditable: true,
                      onEdit: () {},
                    ),

                    // Alergias → navega a MockAllergiesScreen
                    _buildInfoCard(
                      icon: Icons.no_food,
                      title: 'Alergias',
                      value: '${_mockAllergies.length} alergias registradas',
                      isEditable: true,
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MockAllergiesScreen()),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Contactos de emergencia
                    _buildSectionTitle('Contactos de Emergencia', Icons.emergency),
                    const _MockEmergencyContactsWidget(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _sacRed, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _sacBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isEditable = false,
    VoidCallback? onEdit,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(icon, color: _sacRed, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isEditable)
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: _sacRed, size: 20),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA: Alergias
// ═════════════════════════════════════════════════════════════════════════════

class MockAllergiesScreen extends StatefulWidget {
  const MockAllergiesScreen({super.key});

  @override
  State<MockAllergiesScreen> createState() => _MockAllergiesScreenState();
}

class _MockAllergiesScreenState extends State<MockAllergiesScreen> {
  final List<_MockAllergy> _allergies = List.from(_mockAllergies);

  void _showAddAllergyDialog() {
    final TextEditingController manualCtrl = TextEditingController();
    final allCatalog = ['Polen', 'Mariscos', 'Penicilina', 'Lactosa', 'Gluten', 'Nueces', 'Látex', 'Ácaros'];
    _MockAllergy? selected;
    bool isManual = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agregar alergia'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Catálogo'), icon: Icon(Icons.list)),
                    ButtonSegment(value: true, label: Text('Manual'), icon: Icon(Icons.edit)),
                  ],
                  selected: {isManual},
                  onSelectionChanged: (s) => setDialogState(() {
                    isManual = s.first;
                    selected = null;
                  }),
                ),
                const SizedBox(height: 16),
                if (isManual)
                  TextField(
                    controller: manualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la alergia *',
                      hintText: 'Ej. Nueces, Látex, Penicilina',
                      border: OutlineInputBorder(),
                    ),
                  )
                else ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar alergia',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      children: allCatalog.map((name) {
                        final isSelected = selected?.name == name;
                        return ListTile(
                          title: Text(name),
                          selected: isSelected,
                          selectedTileColor: _sacRed.withOpacity(0.1),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: _sacRed) : null,
                          onTap: () => setDialogState(() {
                            selected = _MockAllergy(_allergies.length + 1, name);
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: _sacBlue),
              onPressed: () {
                final newName = isManual ? manualCtrl.text.trim() : selected?.name;
                if (newName != null && newName.isNotEmpty) {
                  setState(() {
                    _allergies.add(_MockAllergy(_allergies.length + 1, newName));
                  });
                  Navigator.pop(ctx);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes seleccionar o ingresar una alergia'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(_MockAllergy allergy) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alergia'),
        content: Text('¿Estás seguro que deseas eliminar la alergia "${allergy.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _sacRed),
            onPressed: () {
              setState(() => _allergies.removeWhere((a) => a.id == allergy.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alergia eliminada correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _sacRed,
        title: const Text(
          'ALERGIAS',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAllergyDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _allergies.isEmpty ? _buildEmptyState() : _buildList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes alergias registradas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus alergias para que el equipo médico esté informado',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddAllergyDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _sacBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Agregar alergia'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allergies.length,
      itemBuilder: (_, index) {
        final allergy = _allergies[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _sacRed.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _sacRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_food, color: _sacRed),
            ),
            title: Text(
              allergy.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: _sacRed),
              onPressed: () => _showDeleteDialog(allergy),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA: Enfermedades
// ═════════════════════════════════════════════════════════════════════════════

class MockDiseasesScreen extends StatefulWidget {
  const MockDiseasesScreen({super.key});

  @override
  State<MockDiseasesScreen> createState() => _MockDiseasesScreenState();
}

class _MockDiseasesScreenState extends State<MockDiseasesScreen> {
  final List<_MockDisease> _diseases = List.from(_mockDiseases);

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _showAddDiseaseSheet() {
    final catalog = [
      'Asma', 'Diabetes Tipo 1', 'Diabetes Tipo 2', 'Hipertensión',
      'Epilepsia', 'Artritis', 'Anemia', 'Hipotiroidismo',
    ];
    final List<String> selected = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccionar enfermedades',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona las enfermedades que padeces para que el equipo médico esté informado.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView(
                  children: catalog.map((name) {
                    final isSelected = selected.contains(name);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(name),
                      activeColor: _sacRed,
                      onChanged: (_) => setSheetState(() {
                        isSelected ? selected.remove(name) : selected.add(name);
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sacRed,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    for (final name in selected) {
                      _diseases.add(_MockDisease(
                        _diseases.length + 1,
                        name,
                        createdAt: DateTime.now(),
                      ));
                    }
                  });
                  Navigator.pop(ctx);
                  if (selected.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enfermedades guardadas correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(_MockDisease disease) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Enfermedad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que deseas eliminar esta enfermedad?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_information, color: _sacRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      disease.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _sacBlack, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _sacRed),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _diseases.removeWhere((d) => d.id == disease.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Enfermedad "${disease.name}" eliminada correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _sacRed,
        title: const Text(
          'ENFERMEDADES',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDiseaseSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: _diseases.isEmpty ? _buildEmptyState() : _buildList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_information_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tienes enfermedades registradas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus enfermedades para que el equipo médico esté informado',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDiseaseSheet,
            icon: const Icon(Icons.add, color: Colors.white, size: 25),
            label: const Text(
              'Agregar Enfermedad',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _sacRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _diseases.length,
      itemBuilder: (_, index) {
        final disease = _diseases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _sacRed.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _sacRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_information, color: _sacRed),
            ),
            title: Text(
              disease.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (disease.description != null && disease.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      disease.description!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Registrada: ${_formatDate(disease.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: _sacRed),
              onPressed: () => _showDeleteDialog(disease),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGET: Contactos de Emergencia (embebido en MockPersonalInfoScreen)
// ═════════════════════════════════════════════════════════════════════════════

class _MockEmergencyContactsWidget extends StatefulWidget {
  const _MockEmergencyContactsWidget();

  @override
  State<_MockEmergencyContactsWidget> createState() => _MockEmergencyContactsWidgetState();
}

class _MockEmergencyContactsWidgetState extends State<_MockEmergencyContactsWidget> {
  final List<_MockContact> _contacts = List.from(_mockContacts);

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '';
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Colors.blue, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.indigo, Colors.pink,
    ];
    int hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _MockEmergencyContactModal(
          onConfirm: (name, phone, relationship) {
            Navigator.pop(ctx);
            setState(() {
              _contacts.add(_MockContact(_contacts.length + 1, name, phone, relationship));
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Contacto de emergencia añadido exitosamente!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(_MockContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Contacto'),
        content: Text(
            '¿Estás seguro que deseas eliminar a ${contact.name} de tus contactos de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _sacRed),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _contacts.removeWhere((c) => c.id == contact.id));
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_contacts.isEmpty)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.contact_emergency_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No se han registrado contactos de emergencia aún.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._contacts.map((c) => _buildContactItem(c)).toList(),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showAddModal,
          icon: const Icon(Icons.add, size: 25, color: Colors.white),
          label: const Text(
            'Agregar Contacto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _sacRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(_MockContact contact) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarColor(contact.name),
              child: Text(
                _getInitials(contact.name),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.relationship,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, size: 18, color: _sacBlack),
                      const SizedBox(width: 3),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                            color: _sacBlack, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: _sacRed, size: 22),
              onPressed: () => _showDeleteDialog(contact),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODAL: Agregar Contacto de Emergencia
// ═════════════════════════════════════════════════════════════════════════════

class _MockEmergencyContactModal extends StatefulWidget {
  final Function(String name, String phone, String relationship) onConfirm;

  const _MockEmergencyContactModal({required this.onConfirm});

  @override
  State<_MockEmergencyContactModal> createState() => _MockEmergencyContactModalState();
}

class _MockEmergencyContactModalState extends State<_MockEmergencyContactModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedRelationship;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CONTACTO DE EMERGENCIA',
                  style: TextStyle(
                      fontSize: 18, color: _sacBlack, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Agrega la información de tu contacto para que tus directivos del club puedan contactarlo en caso de emergencia.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Campo nombre
                TextFormField(
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  decoration: InputDecoration(
                    labelText: 'NOMBRE COMPLETO',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'El nombre es requerido' : null,
                ),
                const SizedBox(height: 12),

                // Campo teléfono
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'TELÉFONO',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v?.length != 10) ? 'El teléfono debe tener 10 dígitos' : null,
                ),
                const SizedBox(height: 16),

                // Selector tipo de relación
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIPO DE RELACIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _sacBlack),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedRelationship,
                          decoration: const InputDecoration(
                            hintText: 'Seleccione el tipo de relación',
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                            prefixIcon: Icon(Icons.people_outline, color: _sacGrey),
                          ),
                          hint: const Text('Seleccione el tipo de relación',
                              style: TextStyle(color: _sacGrey)),
                          icon: const Icon(Icons.arrow_drop_down, color: _sacBlack),
                          isExpanded: true,
                          items: _relationshipTypes
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedRelationship = v),
                          validator: (v) =>
                              v == null ? 'Seleccione el tipo de relación' : null,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sacRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      widget.onConfirm(
                        _nameCtrl.text,
                        _phoneCtrl.text,
                        _selectedRelationship!,
                      );
                    }
                  },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

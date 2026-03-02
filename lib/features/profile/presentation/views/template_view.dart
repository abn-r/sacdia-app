import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// ─── Colores mock ────────────────────────────────────────────────────────────
const Color sacRed = Color(0xFFCC0000);
const Color sacBlack = Color(0xFF1A1A1A);
const Color sacGrey = Color(0xFF9E9E9E);
const Color sacYellow = Color(0xFFFFC107);

// Colores de categorías
const Color catAdra = Color(0xFFE53935);
const Color catAgropecuarias = Color(0xFF8BC34A);
const Color catCienciasSalud = Color(0xFF0288D1);
const Color catDomesticas = Color(0xFFFF8F00);
const Color catHabilidadesManuales = Color(0xFF6D4C41);
const Color catMisioneras = Color(0xFF7B1FA2);
const Color catNaturaleza = Color(0xFF2E7D32);
const Color catProfesionales = Color(0xFF37474F);
const Color catRecreativas = Color(0xFFE91E63);

// ─── Datos mock ───────────────────────────────────────────────────────────────

class _MockHonor {
  final String name;
  const _MockHonor(this.name);
}

class _MockCategory {
  final String name;
  final Color color;
  final IconData icon;
  final List<_MockHonor> honors;
  const _MockCategory({
    required this.name,
    required this.color,
    required this.icon,
    required this.honors,
  });
}

const _mockCategories = [
  _MockCategory(
    name: 'Naturaleza',
    color: catNaturaleza,
    icon: Icons.forest,
    honors: [
      _MockHonor('Aves'),
      _MockHonor('Mariposas'),
      _MockHonor('Árboles'),
      _MockHonor('Reptiles'),
      _MockHonor('Peces'),
    ],
  ),
  _MockCategory(
    name: 'Recreativas',
    color: catRecreativas,
    icon: Icons.sports_handball,
    honors: [
      _MockHonor('Natación'),
      _MockHonor('Senderismo'),
      _MockHonor('Ciclismo'),
    ],
  ),
  _MockCategory(
    name: 'Habilidades Manuales',
    color: catHabilidadesManuales,
    icon: Icons.handyman,
    honors: [
      _MockHonor('Carpintería'),
      _MockHonor('Costura'),
      _MockHonor('Cerámica'),
      _MockHonor('Tejido'),
    ],
  ),
  _MockCategory(
    name: 'Ciencias y Salud',
    color: catCienciasSalud,
    icon: Icons.medical_services,
    honors: [
      _MockHonor('Primeros Auxilios'),
      _MockHonor('Nutrición'),
    ],
  ),
  _MockCategory(
    name: 'Misioneras',
    color: catMisioneras,
    icon: Icons.public,
    honors: [
      _MockHonor('Evangelismo'),
      _MockHonor('Mayordomía'),
      _MockHonor('Literatura'),
    ],
  ),
];

// ─── Widgets de clases (mockup estático) ─────────────────────────────────────

class _MockStatusCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _MockStatusCircle({
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : Colors.grey[200],
            border: Border.all(
              color: active ? color : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label[0],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.grey[500],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: active ? color : Colors.grey[500],
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─── Pantalla principal ───────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedClub = 'club-001';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: sacRed,
        elevation: 0,
        title: const Text(
          'PERFIL',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 24, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado de usuario ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Carlos Andrés Méndez López',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: sacBlack,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rol Activo: Líder de Club',
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                          Text(
                            'Club: Club Renacer Guatemala (2025)',
                            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sacRed,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        child: const Icon(Icons.person, size: 60, color: sacGrey),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Selector de club ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleccionar Contexto de Club Activo:',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: sacBlack),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: sacGrey, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedClub,
                          icon: const Icon(Icons.arrow_drop_down, color: sacRed),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedClub = newValue);
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'club-001',
                              child: Text(
                                'Líder de Club en Club Renacer Guatemala (2025)',
                                style: TextStyle(color: sacBlack, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'club-002',
                              child: Text(
                                'Consejero en Club Faro de Luz Quetzaltenango (2025)',
                                style: TextStyle(color: sacBlack, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Sección de clases progresivas ──────────────────────────────
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Guías Mayores (activo)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'El usuario está investido de la clase de Guías Mayores'),
                              ),
                            );
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sacRed.withOpacity(0.1),
                              border: Border.all(color: sacRed, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                'GM',
                                style: TextStyle(
                                  color: sacRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Círculos de clases
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          _MockStatusCircle(
                              label: 'Amigo', color: sacRed, active: true),
                          _MockStatusCircle(
                              label: 'Compañero',
                              color: Color(0xFF1565C0),
                              active: true),
                          _MockStatusCircle(
                              label: 'Explorador',
                              color: Color(0xFF2E7D32),
                              active: true),
                          _MockStatusCircle(
                              label: 'Orientador',
                              color: Color(0xFFF57F17),
                              active: false),
                          _MockStatusCircle(
                              label: 'Viajero',
                              color: Color(0xFF6A1B9A),
                              active: false),
                          _MockStatusCircle(
                              label: 'Guía',
                              color: Color(0xFF37474F),
                              active: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Encabezado de especialidades ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Especialidades',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: sacBlack,
                      ),
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            'Actualizado: Hace 5 min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: sacBlack, size: 30),
                          onPressed: () {},
                          tooltip: 'Actualizar especialidades',
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: sacRed, size: 30),
                          tooltip: 'Agregar especialidad',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Lista de categorías con especialidades ─────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _mockCategories.map((category) {
                  return _buildCategorySection(category);
                }).toList(),
              ),

              const SizedBox(height: 30),

              // ── Botones de acción ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sacBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Información Personal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sacYellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Actualizar perfil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(_MockCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: category.color.withAlpha(100),
                  width: 1.5,
                ),
                bottom: BorderSide(
                  color: category.color.withAlpha(100),
                  width: 1.5,
                ),
              ),
              color: category.color.withAlpha(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: category.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    category.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: category.honors.length,
            itemBuilder: (context, index) {
              return _buildHonorItem(category.honors[index], category.color);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHonorItem(_MockHonor honor, Color categoryColor) {
    final String initials = honor.name
        .split(' ')
        .take(2)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join('');

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildInitialsContainer(initials, categoryColor),
            ),
          ),
        ),
        Text(
          honor.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: sacBlack,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInitialsContainer(String initials, Color categoryColor) {
    return Container(
      decoration: BoxDecoration(
        color: categoryColor.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: categoryColor.withAlpha(50), width: 1),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: categoryColor,
          ),
        ),
      ),
    );
  }
}

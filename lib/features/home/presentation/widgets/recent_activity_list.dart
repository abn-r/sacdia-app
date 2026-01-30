import 'package:flutter/material.dart';

/// Widget para mostrar la lista de actividades recientes
class RecentActivityList extends StatelessWidget {
  final List<String> activities;

  const RecentActivityList({
    Key? key,
    required this.activities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: activities.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: const Icon(Icons.history),
            ),
            title: Text(activity),
            subtitle: Text('Hace ${index + 1} ${index == 0 ? 'hora' : 'horas'}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                // Mostrar opciones para esta actividad
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.visibility),
                        title: const Text('Ver detalles'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ver detalles de: $activity')),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Eliminar de historial'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Actividad eliminada: $activity')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

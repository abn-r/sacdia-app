import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget para el encabezado de bienvenida del dashboard
class WelcomeHeader extends StatelessWidget {
  final String userName;
  final String? userAvatar;

  const WelcomeHeader({
    super.key,
    required this.userName,
    this.userAvatar,
  });

  /// Obtiene el saludo según la hora del día
  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.sacGreen,
            AppColors.sacGreenLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Avatar del usuario
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            backgroundImage: userAvatar != null
                ? NetworkImage(userAvatar!)
                : null,
            child: userAvatar == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sacGreen,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Saludo y nombre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

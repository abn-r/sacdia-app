import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/widgets/theme_toggle.dart';
import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/recent_activity_list.dart';

/// Vista principal de la aplicación después del login
class HomeView extends ConsumerStatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    // Cargar los datos del dashboard al iniciar
    Future.microtask(() => 
      ref.read(homeNotifierProvider.notifier).loadDashboardData()
    );
    // La redirección se maneja ahora centralmente en AuthGate
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          // Toggle de tema
          const ThemeToggle(),
          const SizedBox(width: 8),
          if (homeState.dashboardData?.hasNotifications ?? false)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedNotification02,
                color: Colors.amber,
                size: 24,
              ),
              onPressed: () {
                ref.read(homeNotifierProvider.notifier).markNotificationsAsRead();
                context.showSnackBar('Notificaciones marcadas como leídas');
              },
            )
          else
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedNotification02,
                color: Colors.grey,
                size: 24,
              ),
              onPressed: () {
                context.showSnackBar('No tienes notificaciones nuevas');
              },
            ),
          IconButton(
            icon: const HugeIcon(
              icon: Icons.logout,
              color: Colors.grey,
              size: 24,
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Estás seguro que deseas cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                try {
                  // Cerrar sesión a través del provider
                  await ref.read(authNotifierProvider.notifier).signOut();

                  // Limpieza adicional forzada de datos locales
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('supabase.auth.token');
                  await prefs.remove('supabase.auth.refresh_token');
                  await prefs.remove('supabase.auth.expires_at');
                  await prefs.remove('supabase.auth.expires_in');
                  await prefs.remove('supabase.auth.user');

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesión cerrada correctamente')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: homeState.isLoading
          ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(
                color: Colors.black,
                radius: 15,
              ),
              SizedBox(height: 16),
              Text('Cargando datos...',
              style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ))
          : homeState.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(homeState.errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(homeNotifierProvider.notifier).loadDashboardData();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(homeNotifierProvider.notifier).loadDashboardData();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homeState.dashboardData?.welcomeMessage ?? '¡Bienvenido!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (user != null)
                          Text(
                            user.name ?? user.email,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 24),
                        if (homeState.dashboardData != null) ...[
                          DashboardCard(
                            title: 'Tareas pendientes',
                            value: homeState.dashboardData!.pendingTasks.toString(),
                            icon: Icons.task_alt,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Actividad reciente',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (homeState.dashboardData!.recentActivities.isNotEmpty)
                            RecentActivityList(
                              activities: homeState.dashboardData!.recentActivities,
                            )
                          else
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No hay actividades recientes'),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.showSnackBar('Función en desarrollo');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

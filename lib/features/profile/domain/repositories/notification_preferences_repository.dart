import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/notification_preferences.dart';

/// Interfaz del repositorio de preferencias de notificación.
abstract class NotificationPreferencesRepository {
  /// Obtiene las preferencias del servidor.
  Future<Either<Failure, NotificationPreferences>> getPreferences();

  /// Actualiza parcialmente las preferencias en el servidor.
  ///
  /// [delta] puede incluir cualquier subconjunto de campos. El servidor aplica
  /// la lógica de cascada (si master=false → subcategorías a false).
  /// Retorna el objeto completo actualizado.
  Future<Either<Failure, NotificationPreferences>> updatePreferences(
    Map<String, bool> delta,
  );
}

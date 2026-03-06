import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_honor.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para registrar (completar) una especialidad de usuario
///
/// Envía los datos completos del formulario de registro al backend,
/// incluyendo fecha, imágenes de evidencia, certificado y documento opcional.
class RegisterUserHonor implements UseCase<UserHonor, RegisterUserHonorParams> {
  final HonorsRepository repository;

  RegisterUserHonor(this.repository);

  @override
  Future<Either<Failure, UserHonor>> call(RegisterUserHonorParams params) async {
    return await repository.registerUserHonor(params);
  }
}

/// Parámetros para registrar una especialidad de usuario
class RegisterUserHonorParams {
  final String userId;
  final int honorId;
  final DateTime date;
  final List<String> images;
  final String certificate;
  final String? document;

  const RegisterUserHonorParams({
    required this.userId,
    required this.honorId,
    required this.date,
    this.images = const [],
    this.certificate = '',
    this.document,
  });

  Map<String, dynamic> toJson() => {
        'honorId': honorId,
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'validate': false,
        'certificate': certificate,
        'images': images,
        if (document != null) 'document': document,
      };
}

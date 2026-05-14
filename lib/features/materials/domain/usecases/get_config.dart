import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_config.dart';
import '../repositories/materials_repository.dart';

/// Caso de uso: obtener configuración bancaria y de entrega del módulo.
class GetConfig implements NoParamsUseCase<MaterialConfig> {
  GetConfig(this._repo);
  final MaterialsRepository _repo;

  @override
  Future<Either<Failure, MaterialConfig>> call() => _repo.getConfig();
}

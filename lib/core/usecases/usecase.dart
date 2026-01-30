import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Caso de uso base abstracto para operaciones que retornan un solo resultado
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Caso de uso base abstracto para operaciones que retornan un stream
abstract class StreamUseCase<Type, Params> {
  Stream<Either<Failure, Type>> call(Params params);
}

/// Caso de uso base abstracto para operaciones sin parámetros
abstract class NoParamsUseCase<Type> {
  Future<Either<Failure, Type>> call();
}

/// Parámetros vacíos para casos de uso que no necesitan parámetros
class NoParams {
  const NoParams();
}

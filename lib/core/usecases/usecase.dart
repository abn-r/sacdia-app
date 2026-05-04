import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Caso de uso base abstracto para operaciones que retornan un solo resultado
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Caso de uso base abstracto para operaciones que retornan un stream
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

/// Caso de uso base abstracto para operaciones sin parámetros
abstract class NoParamsUseCase<T> {
  Future<Either<Failure, T>> call();
}

/// Parámetros vacíos para casos de uso que no necesitan parámetros
class NoParams {
  const NoParams();
}

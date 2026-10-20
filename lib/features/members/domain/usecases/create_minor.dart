import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/create_minor.dart';
import '../repositories/members_repository.dart';

/// `POST /club-sections/:clubSectionId/dependents`: un director registra a un
/// menor bajo custodia del club (solicitud pendiente, consentimiento pendiente).
class CreateMinor implements UseCase<CreatedMinor, CreateMinorInput> {
  final MembersRepository repository;

  CreateMinor(this.repository);

  @override
  Future<Either<Failure, CreatedMinor>> call(CreateMinorInput params) =>
      repository.createMinor(params);
}

import 'package:equatable/equatable.dart';

/// Código para que la familia de un menor bajo custodia del club lo reclame
/// (`POST /club-sections/:clubSectionId/dependents/:userId/claim-codes`, 7 días).
class IssuedClaimCode extends Equatable {
  final String code;
  final DateTime expiresAt;

  const IssuedClaimCode({required this.code, required this.expiresAt});

  @override
  List<Object?> get props => [code, expiresAt];
}

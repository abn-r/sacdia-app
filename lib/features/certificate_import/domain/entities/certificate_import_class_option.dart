import 'package:equatable/equatable.dart';

/// One class the member can pick, from the import catalog (includes classes
/// no longer offered and institutional ones).
class CertificateImportClassOption extends Equatable {
  const CertificateImportClassOption({
    required this.id,
    required this.name,
    this.assetCode,
    this.clubTypeId,
    this.institutional = false,
  });

  final int id;
  final String name;
  final String? assetCode;
  final int? clubTypeId;

  /// Goes to the institutional circuit: approving it creates no enrollment.
  final bool institutional;

  @override
  List<Object?> get props => [id, name, assetCode, clubTypeId, institutional];
}

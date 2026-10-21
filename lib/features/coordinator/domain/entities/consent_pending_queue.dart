import 'package:equatable/equatable.dart';

import '../../../members/domain/entities/join_request.dart';

/// "club · tipo · distrito", sin los datos que falten. Es el mismo rótulo en la
/// fila de una ficha y en el resumen por sección.
String consentLocationLabel({
  String? clubName,
  String? clubTypeName,
  String? districtName,
}) =>
    [clubName, clubTypeName, districtName]
        .map((part) => part?.trim())
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' · ');

/// Una ficha de consentimiento que espera verificación, con la sección a la que
/// pertenece (`GET /coordination/me/consent-pending`).
class ConsentPendingItem extends Equatable {
  /// La solicitud tal como la abre la verificación de la ficha.
  final JoinRequest request;
  final int? clubSectionId;
  final String? clubName;
  final String? clubTypeName;
  final String? districtName;

  /// Cuándo se subió la ficha vigente; la cola va de la más antigua a la más
  /// nueva.
  final DateTime? formUploadedAt;

  const ConsentPendingItem({
    required this.request,
    this.clubSectionId,
    this.clubName,
    this.clubTypeName,
    this.districtName,
    this.formUploadedAt,
  });

  String get assignmentId => request.assignmentId;

  String get caption => consentLocationLabel(
        clubName: clubName,
        clubTypeName: clubTypeName,
        districtName: districtName,
      );

  @override
  List<Object?> get props => [
        request,
        clubSectionId,
        clubName,
        clubTypeName,
        districtName,
        formUploadedAt,
      ];
}

/// Cuántas fichas esperan en una sección del alcance (`by_section`).
class ConsentPendingSection extends Equatable {
  final int clubSectionId;
  final String? clubName;
  final String? clubTypeName;
  final String? districtName;
  final int pendingConsentCount;

  const ConsentPendingSection({
    required this.clubSectionId,
    this.clubName,
    this.clubTypeName,
    this.districtName,
    required this.pendingConsentCount,
  });

  String get label => consentLocationLabel(
        clubName: clubName,
        clubTypeName: clubTypeName,
        districtName: districtName,
      );

  ConsentPendingSection copyWith({int? pendingConsentCount}) =>
      ConsentPendingSection(
        clubSectionId: clubSectionId,
        clubName: clubName,
        clubTypeName: clubTypeName,
        districtName: districtName,
        pendingConsentCount: pendingConsentCount ?? this.pendingConsentCount,
      );

  @override
  List<Object?> get props => [
        clubSectionId,
        clubName,
        clubTypeName,
        districtName,
        pendingConsentCount,
      ];
}

/// Una página de la cola de fichas por verificar de todas las secciones que
/// cubre el coordinador.
class ConsentPendingPage extends Equatable {
  final List<ConsentPendingItem> items;

  /// Fichas por verificar en TODA la cola, no solo en esta página.
  final int total;
  final int limit;
  final int offset;
  final List<ConsentPendingSection> bySection;

  const ConsentPendingPage({
    this.items = const [],
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
    this.bySection = const [],
  });

  @override
  List<Object?> get props => [items, total, limit, offset, bySection];
}

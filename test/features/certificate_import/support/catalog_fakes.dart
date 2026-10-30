import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/certificate_import/domain/entities/certificate_import_class_option.dart';
import 'package:sacdia_app/features/certificate_import/presentation/providers/certificate_import_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/usecases/get_honors.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/club_type_model.dart';

import '../../../support/instructor_fakes.dart';

const clubTypes = [
  ClubTypeModel(clubTypeId: 1, name: 'Conquistadores'),
  ClubTypeModel(clubTypeId: 2, name: 'Aventureros'),
  ClubTypeModel(clubTypeId: 3, name: 'Guías Mayores'),
];

const categories = [
  HonorCategory(id: 3, name: 'Salud'),
  HonorCategory(id: 7, name: 'Naturaleza'),
];

const firstAid = Honor(
  id: 10,
  name: 'Primeros Auxilios',
  categoryId: 3,
  categoryName: 'Salud',
);
const knots = Honor(
  id: 11,
  name: 'Nudos',
  categoryId: 7,
  categoryName: 'Naturaleza',
);

/// Conquistadores classes in catalog order, plus one institutional.
const conquistadoresClasses = [
  CertificateImportClassOption(
    id: 1,
    name: 'Amigo',
    assetCode: 'CQ-01',
    clubTypeId: 1,
  ),
  CertificateImportClassOption(
    id: 3,
    name: 'Explorador',
    assetCode: 'CQ-02',
    clubTypeId: 1,
  ),
  CertificateImportClassOption(
    id: 9,
    name: 'Guía Mayor Instructor',
    assetCode: 'GM-03',
    clubTypeId: 1,
    institutional: true,
  ),
];

/// Records every search and answers with [handler] (everything by default).
class FakeGetHonors extends Fake implements GetHonors {
  FakeGetHonors([this.handler]);

  final calls = <GetHonorsParams>[];
  Either<Failure, List<Honor>> Function(GetHonorsParams params)? handler;

  @override
  Future<Either<Failure, List<Honor>>> call(
    GetHonorsParams params, {
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(params);
    return handler?.call(params) ?? const Right([firstAid, knots]);
  }
}

/// Catalog providers the editor reads, without touching the network.
List<Override> catalogOverrides({
  FakeGetHonors? honors,
  FakeInstructorSearch? instructors,
  Future<List<CertificateImportClassOption>> Function(int clubTypeId)? classes,
}) {
  return [
    (instructors ?? FakeInstructorSearch()).override,
    clubTypesProvider.overrideWith((ref) async => clubTypes),
    honorCategoriesProvider.overrideWith((ref) async => categories),
    getHonorsProvider.overrideWithValue(honors ?? FakeGetHonors()),
    certificateImportClassCatalogProvider.overrideWith(
      (ref, clubTypeId) async => classes != null
          ? classes(clubTypeId)
          : clubTypeId == 1
              ? conquistadoresClasses
              : const <CertificateImportClassOption>[],
    ),
  ];
}

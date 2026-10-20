import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/members/domain/entities/annual_continuation.dart';
import 'package:sacdia_app/features/members/domain/entities/assignable_role.dart';
import 'package:sacdia_app/features/members/domain/entities/claim_code.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/domain/entities/consent_verification_result.dart';
import 'package:sacdia_app/features/members/domain/entities/create_minor.dart';
import 'package:sacdia_app/features/members/domain/entities/join_request.dart';
import 'package:sacdia_app/features/members/domain/repositories/members_repository.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Traducciones reales (`es`) para comprobar el texto de verdad.
class FileAssetLoader extends AssetLoader {
  const FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

Future<void> initLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// Monta [home] con español real y texto reducido (0.5), como el resto de los
/// tests de widget del proyecto.
///
/// [size] y [textScale] permiten reproducir un teléfono real (p. ej. 402×874
/// con texto al 100 %): con el 0.5 por defecto un rótulo largo nunca se corta.
Future<void> pumpMembersApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
  Size size = const Size(800, 2400),
  double textScale = 0.5,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Bloque `consent` del backend para una solicitud de menor.
Map<String, Object?> consentJson({
  String status = 'pending',
  bool evidence = false,
}) =>
    {
      'required': true,
      'dependent': true,
      'guardianship_id': 'gs-1',
      'status': status,
      'evidence_uploaded': evidence,
      'guardians': [
        {
          'display_name': 'María Pérez',
          'relationship_type_name': 'Madre',
          'is_primary': true,
        },
      ],
    };

/// Solicitud de ingreso de un menor, tal como la lista el backend.
JoinRequest minorRequest({
  String status = 'pending',
  bool evidence = false,
  String name = 'Ana',
}) =>
    JoinRequest(
      assignmentId: '12/membership-requests/req-1',
      userId: 'ana-1',
      name: name,
      paternalSurname: 'Pérez',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
      consent: JoinRequestConsent(
        guardianshipId: 'gs-1',
        status: JoinRequestConsentStatus.parse(status),
        evidenceUploaded: evidence,
        guardians: const [
          ConsentGuardianRef(
            displayName: 'María Pérez',
            relationshipTypeName: 'Madre',
            isPrimary: true,
          ),
        ],
      ),
    );

JoinRequest adultRequest() => JoinRequest(
      assignmentId: '12/membership-requests/req-2',
      userId: 'luis-1',
      name: 'Luis',
      paternalSurname: 'Soto',
      status: JoinRequestStatus.pending,
      requestedAt: DateTime(2026, 10, 12),
    );

/// Repositorio configurable que registra cada llamada.
class FakeMembersRepository implements MembersRepository {
  List<JoinRequest> requests = [];
  List<ClubMember> members = [];

  Either<Failure, JoinRequest>? approveResult;
  Either<Failure, bool> assignRoleResult = const Right(true);
  Either<Failure, ConsentEvidenceReceipt> uploadResult = const Right(
    ConsentEvidenceReceipt(
      evidenceId: 'ev-1',
      contentType: 'application/pdf',
      sizeBytes: 2048,
    ),
  );
  Either<Failure, ConsentEvidenceAccess> evidenceResult = Right(
    ConsentEvidenceAccess(
      url: 'https://signed.example.com/form.jpg',
      expiresIn: 900,
      contentType: 'image/jpeg',
      uploadedAt: DateTime.utc(2026, 10, 19, 15, 30),
      uploadedByDisplayName: 'Laura Díaz',
    ),
  );

  /// Una respuesta por llamada, en orden; la última se repite.
  List<Either<Failure, ConsentVerificationResult>> verifyResults = [
    const Right(
      ConsentVerificationResult(
        guardianshipId: 'gs-1',
        approved: true,
        verificationMethod: 'director_paper_form',
      ),
    ),
  ];

  /// Alta de un menor por un director (Fase 3c).
  Either<Failure, CreatedMinor> createMinorResult = const Right(
    CreatedMinor(
      userId: 'luis-9',
      name: 'Luis',
      birthday: '2016-02-10',
      age: 10,
      guardianshipId: 'gs-9',
      assignmentId: 'req-9',
      clubSectionId: 12,
    ),
  );
  Either<Failure, IssuedClaimCode> claimCodeResult = Right(
    IssuedClaimCode(
      code: '7KQ4-M9TX',
      expiresAt: DateTime.utc(2026, 10, 27, 10),
    ),
  );

  final createMinorInputs = <CreateMinorInput>[];
  final claimCodeCalls = <({int clubSectionId, String dependentUserId})>[];
  final approveCalls = <String>[];
  final assignRoleCalls = <({String userId, String role})>[];
  final uploadCalls = <({String assignmentId, String fileName})>[];
  final evidenceReads = <String>[];
  final verifyCalls = <({String assignmentId, bool approve})>[];

  @override
  Future<Either<Failure, List<JoinRequest>>> getJoinRequests({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) async =>
      Right(requests);

  @override
  Future<Either<Failure, List<ClubMember>>> getClubMembers({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) async =>
      Right(members);

  @override
  Future<Either<Failure, JoinRequest>> approveJoinRequest(
    String assignmentId,
  ) async {
    approveCalls.add(assignmentId);
    return approveResult ?? Right(requests.first);
  }

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String assignmentId,
    required ConsentEvidenceLocalFile file,
  }) async {
    uploadCalls.add((assignmentId: assignmentId, fileName: file.name));
    return uploadResult;
  }

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
    String assignmentId,
  ) async {
    evidenceReads.add(assignmentId);
    return evidenceResult;
  }

  @override
  Future<Either<Failure, ConsentVerificationResult>> verifyConsent({
    required String assignmentId,
    required bool approve,
  }) async {
    verifyCalls.add((assignmentId: assignmentId, approve: approve));
    final index = verifyCalls.length - 1;
    return verifyResults[
        index < verifyResults.length ? index : verifyResults.length - 1];
  }

  // ── No usados por estos tests ─────────────────────────────────────────────

  @override
  Future<Either<Failure, ClubMember>> getMemberDetail(String userId,
          {RequestCancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, JoinRequest>> rejectJoinRequest(
          String assignmentId) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, bool>> assignClubRole({
    required int clubId,
    required int sectionId,
    required String userId,
    required String role,
  }) async {
    assignRoleCalls.add((userId: userId, role: role));
    return assignRoleResult;
  }

  /// Sin endpoint de roles asignables: la vista usa su lista de respaldo.
  @override
  Future<Either<Failure, AssignableRolesResult>> getAssignableRoles({
    required int clubId,
    required int sectionId,
    required String userId,
  }) async =>
      const Left(ServerFailure(message: 'assignable roles unavailable'));

  @override
  Future<Either<Failure, bool>> removeClubRole(String assignmentId) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<AnnualContinuation>>> getAnnualContinuations(
          int sectionId) async =>
      const Right([]);

  @override
  Future<Either<Failure, ContinuationBatchResult>> submitAnnualContinuations({
    required int sectionId,
    required List<String> userIds,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, CreatedMinor>> createMinor(
      CreateMinorInput input) async {
    createMinorInputs.add(input);
    return createMinorResult;
  }

  @override
  Future<Either<Failure, IssuedClaimCode>> issueClaimCode({
    required int clubSectionId,
    required String dependentUserId,
  }) async {
    claimCodeCalls
        .add((clubSectionId: clubSectionId, dependentUserId: dependentUserId));
    return claimCodeResult;
  }
}

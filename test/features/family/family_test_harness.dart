import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent_progress_summary.dart';
import 'package:sacdia_app/features/family/domain/entities/supervised_login.dart';
import 'package:sacdia_app/features/family/domain/repositories/family_repository.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/post_registration/data/models/relationship_type_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'family_fixtures.dart';

/// Carga las traducciones reales desde `assets/translations` para que los
/// tests comprueben el texto en español de verdad (y que las llaves existan).
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

const guardianUser = UserEntity(
  id: 'guardian-1',
  email: 'maria@example.com',
  name: 'María',
  postRegisterComplete: true,
);

/// Repositorio configurable. Registra cada llamada.
class FakeFamilyRepository implements FamilyRepository {
  Either<Failure, FamilyOverview> overview = Right(
    FamilyOverview(dependents: [summary()], maxDependents: 10),
  );
  Either<Failure, DependentDetail> detail =
      const Left(ServerFailure(message: 'unset'));
  Either<Failure, DependentSummary> created = Right(summary());
  Either<Failure, IssuedLinkCode> issued = Right(
    IssuedLinkCode(
      code: '7KQ4-M9TX',
      expiresAt: DateTime.utc(2026, 10, 22, 10),
    ),
  );
  Either<Failure, DependentSummary> redeemed = Right(summary());
  Either<Failure, RevokeResult> revoked = const Right(
    RevokeResult(guardianshipId: 'gs-1', outcome: DependentOutcome.frozen),
  );
  Either<Failure, List<DeletionImpactEntry>> impact = const Right([]);
  Either<Failure, ConsentEvidenceReceipt> evidenceUploaded = Right(
    ConsentEvidenceReceipt(
      evidenceId: 'ev-1',
      contentType: 'application/pdf',
      sizeBytes: 1234,
      uploadedAt: DateTime.utc(2026, 10, 19, 12),
    ),
  );
  Either<Failure, ConsentEvidenceAccess> evidenceAccess = Right(
    ConsentEvidenceAccess(
      url: 'https://signed.example.com/form.jpg',
      expiresIn: 900,
      contentType: 'image/jpeg',
      uploadedAt: DateTime.utc(2026, 10, 19, 12),
    ),
  );

  Either<Failure, SupervisedLoginStatus> loginStatus = const Right(
    SupervisedLoginStatus(eligible: true),
  );
  Either<Failure, EnabledSupervisedLogin> enabled = const Right(
    EnabledSupervisedLogin(
      supervisedLogin: SupervisedLoginInfo(
        method: SupervisedLoginMethod.handle,
        loginHandle: 'ana-7kq4m9',
      ),
      devicesRevoked: 0,
    ),
  );
  Either<Failure, SupervisedLoginInfo> disabled = Right(
    SupervisedLoginInfo(
      method: SupervisedLoginMethod.handle,
      loginHandle: 'ana-7kq4m9',
      disabledAt: DateTime.utc(2026, 10, 19),
      disabledReason: 'guardian',
    ),
  );
  Either<Failure, SupervisedLoginInfo> reactivated = const Right(
    SupervisedLoginInfo(
      method: SupervisedLoginMethod.handle,
      loginHandle: 'ana-7kq4m9',
    ),
  );
  Either<Failure, PasswordResetResult> passwordReset =
      const Right(PasswordResetResult(sessionsRevoked: 2));
  Either<Failure, DependentProgressSummary> progress = const Right(
    DependentProgressSummary(userId: 'ana-1', name: 'Ana', age: 14),
  );

  Either<Failure, ConsentEvidenceReceipt>? actingEvidenceUploaded;
  final actingEvidenceUploads = <({String dependentUserId, String fileName})>[];

  final enableCalls = <({
    String dependentId,
    SupervisedLoginMethod method,
    String password,
    String? email,
  })>[];
  final disableCalls = <String>[];
  final reactivateCalls = <({String dependentId, String? password})>[];
  final passwordCalls = <({String dependentId, String? password})>[];
  final summaryCalls = <String>[];
  int loginStatusCalls = 0;

  final createInputs = <CreateDependentInput>[];
  final redeemCalls = <({String code, String relationshipTypeId})>[];
  final revokeCalls = <({String guardianshipId, bool removedByPrimary})>[];
  final issueCalls = <String>[];
  final evidenceUploads = <({String dependentId, String fileName})>[];
  final evidenceReads = <String>[];
  int listCalls = 0;

  @override
  Future<Either<Failure, FamilyOverview>> listDependents() async {
    listCalls++;
    return overview;
  }

  @override
  Future<Either<Failure, DependentDetail>> getDependent(String id) async =>
      detail;

  @override
  Future<Either<Failure, DependentSummary>> createDependent(
    CreateDependentInput input,
  ) async {
    createInputs.add(input);
    return created;
  }

  @override
  Future<Either<Failure, IssuedLinkCode>> issueLinkCode(String id) async {
    issueCalls.add(id);
    return issued;
  }

  @override
  Future<Either<Failure, DependentSummary>> redeemLinkCode({
    required String code,
    required String relationshipTypeId,
    required bool swornDeclaration,
  }) async {
    redeemCalls.add((code: code, relationshipTypeId: relationshipTypeId));
    return redeemed;
  }

  @override
  Future<Either<Failure, RevokeResult>> revoke({
    required String guardianshipId,
    required bool removedByPrimary,
  }) async {
    revokeCalls.add((
      guardianshipId: guardianshipId,
      removedByPrimary: removedByPrimary,
    ));
    return revoked;
  }

  @override
  Future<Either<Failure, List<DeletionImpactEntry>>> deletionImpact() async =>
      impact;

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String dependentId,
    required ConsentEvidenceLocalFile file,
  }) async {
    evidenceUploads.add((dependentId: dependentId, fileName: file.name));
    return evidenceUploaded;
  }

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
    String dependentId,
  ) async {
    evidenceReads.add(dependentId);
    return evidenceAccess;
  }

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>>
      uploadConsentEvidenceWhileActing({
    required String dependentUserId,
    required ConsentEvidenceLocalFile file,
  }) async {
    actingEvidenceUploads
        .add((dependentUserId: dependentUserId, fileName: file.name));
    return actingEvidenceUploaded ?? evidenceUploaded;
  }

  @override
  Future<Either<Failure, SupervisedLoginStatus>> getSupervisedLogin(
    String dependentId,
  ) async {
    loginStatusCalls++;
    return loginStatus;
  }

  @override
  Future<Either<Failure, EnabledSupervisedLogin>> enableSupervisedLogin({
    required String dependentId,
    required SupervisedLoginMethod method,
    required String password,
    String? email,
  }) async {
    enableCalls.add((
      dependentId: dependentId,
      method: method,
      password: password,
      email: email,
    ));
    return enabled;
  }

  @override
  Future<Either<Failure, SupervisedLoginInfo>> disableSupervisedLogin({
    required String dependentId,
    String? reason,
  }) async {
    disableCalls.add(dependentId);
    return disabled;
  }

  @override
  Future<Either<Failure, SupervisedLoginInfo>> reactivateSupervisedLogin({
    required String dependentId,
    String? password,
  }) async {
    reactivateCalls.add((dependentId: dependentId, password: password));
    return reactivated;
  }

  @override
  Future<Either<Failure, PasswordResetResult>> resetSupervisedPassword({
    required String dependentId,
    String? password,
  }) async {
    passwordCalls.add((dependentId: dependentId, password: password));
    return passwordReset;
  }

  @override
  Future<Either<Failure, DependentProgressSummary>> getProgressSummary(
    String dependentId,
  ) async {
    summaryCalls.add(dependentId);
    return progress;
  }
}

/// `AuthNotifier` fijo que registra los cambios de perfil.
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier([this.user = guardianUser]);

  UserEntity? user;
  SwitchProfileOutcome outcome = SwitchProfileOutcome.entered;
  final switchCalls = <({String? id, String? firstName})>[];

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentId, {
    String? firstName,
  }) async {
    switchCalls.add((id: dependentId, firstName: firstName));
    return outcome;
  }

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async =>
      user;
}

const legalDocs = [
  LegalDocument(
    documentType: LegalDocumentTypes.terms,
    version: '1.0.0-store',
    url: 'https://example.com/terms',
  ),
  LegalDocument(
    documentType: LegalDocumentTypes.privacy,
    version: '1.0.1-store',
    url: 'https://example.com/privacy',
  ),
];

List<Override> familyOverrides({
  required FakeFamilyRepository repo,
  required FakeAuthNotifier auth,
  List<LegalDocument> legal = legalDocs,
}) =>
    [
      familyRepositoryProvider.overrideWithValue(repo),
      authNotifierProvider.overrideWith(() => auth),
      // El selector de Mi familia usa SOLO el endpoint de tutoría.
      guardianshipRelationshipTypesProvider.overrideWith(
        (ref) async => const [
          RelationshipTypeModel(id: 'rel-1', name: 'Madre'),
          RelationshipTypeModel(id: 'rel-2', name: 'Padre'),
        ],
      ),
      // Catálogo completo (contactos de emergencia): no debe verse aquí.
      relationshipTypesProvider.overrideWith(
        (ref) async => const [
          RelationshipTypeModel(id: 'rel-9', name: 'Primo'),
        ],
      ),
      currentLegalDocumentsProvider.overrideWith((ref) async => legal),
    ];

/// Monta [routes] con un `GoRouter`, español real y texto reducido (0.5): los
/// tests de widget del proyecto usan ese escalado.
Future<GoRouter> pumpFamilyApp(
  WidgetTester tester, {
  required List<GoRoute> routes,
  required List<Override> overrides,
  String initialLocation = '/',
}) async {
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
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
          builder: (context) => MaterialApp.router(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(0.5),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}

/// Página de relleno que muestra su ruta, para comprobar la navegación.
GoRoute stubRoute(String path) => GoRoute(
      path: path,
      builder: (_, state) => Scaffold(body: Text('route:${state.uri.path}')),
    );

/// Monta un `GoRouter` ya construido (p. ej. el `routerProvider` real) dentro
/// de [container], con español real y texto reducido.
Future<void> pumpLocalizedRouterApp(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp.router(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(0.5),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

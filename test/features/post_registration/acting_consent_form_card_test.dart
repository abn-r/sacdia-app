import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/dio_client.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/family/data/datasources/family_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/acting_consent_form_card.dart';

import '../family/family_test_harness.dart';

UserEntity _acting({
  String consent = 'pending',
  List<String> scopes = const [
    'self:read',
    'registration:write',
    'consent:evidence'
  ],
  String dependent = 'ana-1',
}) =>
    UserEntity(
      id: dependent,
      name: 'Ana',
      postRegisterComplete: false,
      actingFor: ActingForInfo(
        actorUserId: 'guardian-1',
        dependentUserId: dependent,
        consentStatus: consent,
        scopes: scopes,
      ),
    );

class _RefreshCountingAuth extends FakeAuthNotifier {
  _RefreshCountingAuth(super.user);

  int refreshes = 0;

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    refreshes++;
    return user;
  }
}

/// Repositorio cuya subida "actuando" se resuelve a mano.
class _GatedRepository extends FakeFamilyRepository {
  Completer<Either<Failure, ConsentEvidenceReceipt>>? gate;

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>>
      uploadConsentEvidenceWhileActing({
    required String dependentUserId,
    required ConsentEvidenceLocalFile file,
  }) {
    final g = gate;
    if (g == null) {
      return super.uploadConsentEvidenceWhileActing(
        dependentUserId: dependentUserId,
        file: file,
      );
    }
    actingEvidenceUploads
        .add((dependentUserId: dependentUserId, fileName: file.name));
    return g.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  const ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');

  group('canUploadConsentWhileActing', () {
    test('needs acting, pending consent and the consent:evidence scope', () {
      expect(canUploadConsentWhileActing(_acting(), acting: ana), isTrue);
    });

    test('not when nobody is being acted for', () {
      expect(canUploadConsentWhileActing(_acting(), acting: null), isFalse);
      expect(canUploadConsentWhileActing(null, acting: ana), isFalse);
      expect(
        canUploadConsentWhileActing(
          const UserEntity(id: 'guardian-1'),
          acting: ana,
        ),
        isFalse,
      );
    });

    test('not once the consent is verified', () {
      expect(
        canUploadConsentWhileActing(_acting(consent: 'verified'), acting: ana),
        isFalse,
      );
    });

    test('not without the scope (older backend: the Phase 2 route remains)',
        () {
      expect(
        canUploadConsentWhileActing(
          _acting(scopes: const ['self:read']),
          acting: ana,
        ),
        isFalse,
      );
    });

    test('not for a different dependent than the one acted for', () {
      expect(
        canUploadConsentWhileActing(
          _acting(dependent: 'luis-1'),
          acting: ana,
        ),
        isFalse,
      );
    });
  });

  group('the card', () {
    late FakeFamilyRepository repo;
    late _RefreshCountingAuth auth;

    Future<void> pump(
      WidgetTester tester, {
      UserEntity? user,
      ActingForSession? session,
      FakeFamilyRepository? repository,
    }) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = repository ?? FakeFamilyRepository();
      auth = _RefreshCountingAuth(user ?? _acting());
      final acting = session ??
          (ActingForSession()
            ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana')));
      await pumpFamilyApp(
        tester,
        overrides: [
          ...familyOverrides(repo: repo, auth: auth),
          actingForSessionProvider.overrideWithValue(acting),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                child: ActingConsentFormCard(
                  picker: ConsentEvidencePicker(
                    pickPdf: () async =>
                        (path: '/tmp/ficha.pdf', name: 'ficha.pdf', size: 2048),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    /// Elige el PDF. La subida arranca sola (sin segundo toque en "Subir").
    Future<void> pickAndUpload(WidgetTester tester) async {
      await tester.tap(find.text('Subir ficha firmada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir un PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Set<String> uploadedIds(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(ActingConsentFormCard)),
        ).read(actingConsentFormUploadedProvider);

    ConsentFormPhase phase(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(ActingConsentFormCard)),
        ).read(consentFormPhaseProvider);

    testWidgets('an acting guardian uploads through the ACTING route',
        (tester) async {
      await pump(tester);

      await pickAndUpload(tester);

      // Por la ruta de "actuar por" (con el id del menor), NO por Mi familia.
      expect(repo.actingEvidenceUploads, [
        (dependentUserId: 'ana-1', fileName: 'ficha.pdf'),
      ]);
      expect(repo.evidenceUploads, isEmpty);
      expect(find.text('Ficha subida. Esperando la verificación del director.'),
          findsOneWidget);
      await tester.pumpAndSettle();
      // Subirla no verifica nada.
      expect(
        find.text(
          'Ficha firmada subida. Esperando la verificación del director.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uploads right after picking, without a second tap',
        (tester) async {
      await pump(tester);

      await pickAndUpload(tester);

      expect(repo.actingEvidenceUploads, hasLength(1));
      // Terminó: ya no queda un archivo esperando el botón "Subir".
      expect(find.text('Subir'), findsNothing);
      expect(find.text('Cambiar'), findsNothing);
      expect(phase(tester), ConsentFormPhase.idle);
      // Queda anotado para que la pantalla final diga que la ficha llegó.
      expect(uploadedIds(tester), {'ana-1'});
    });

    testWidgets('reports uploading while the request is in flight',
        (tester) async {
      final gated = _GatedRepository()
        ..gate = Completer<Either<Failure, ConsentEvidenceReceipt>>();
      await pump(tester, repository: gated);

      await pickAndUpload(tester);

      expect(gated.actingEvidenceUploads, hasLength(1));
      expect(phase(tester), ConsentFormPhase.uploading);

      gated.gate!.complete(gated.evidenceUploaded);
      await tester.pumpAndSettle();
      expect(phase(tester), ConsentFormPhase.idle);
    });

    testWidgets('a failed upload keeps the file as pending until a retry works',
        (tester) async {
      await pump(tester);
      repo.actingEvidenceUploaded = const Left(
        ServerFailure(message: 'RAW', code: 500),
      );

      await pickAndUpload(tester);
      await tester.pumpAndSettle();

      expect(phase(tester), ConsentFormPhase.pendingFile);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(uploadedIds(tester), isEmpty);

      repo.actingEvidenceUploaded = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(repo.actingEvidenceUploads, hasLength(2));
      expect(phase(tester), ConsentFormPhase.idle);
    });

    testWidgets('a verified consent mid-upload refreshes the user (409)',
        (tester) async {
      await pump(tester);
      repo.actingEvidenceUploaded = const Left(
        ServerFailure(
          message: 'RAW',
          code: 409,
          errorCode: 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED',
        ),
      );

      await pickAndUpload(tester);

      expect(auth.refreshes, 1);
      expect(find.textContaining('RAW'), findsNothing);
    });

    testWidgets('an unavailable bucket (503) is explained by code',
        (tester) async {
      await pump(tester);
      repo.actingEvidenceUploaded = const Left(
        ServerFailure(
          message: 'RAW',
          code: 503,
          errorCode: 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
        ),
      );

      await pickAndUpload(tester);

      expect(find.textContaining('RAW'), findsNothing);
      expect(auth.refreshes, 0);
    });

    testWidgets('is hidden once the consent is verified', (tester) async {
      await pump(tester, user: _acting(consent: 'verified'));
      expect(
          find.byKey(const ValueKey('acting_consent_form_card')), findsNothing);
    });

    testWidgets('is hidden for a guardian who is not acting', (tester) async {
      await pump(tester, session: ActingForSession());
      expect(
          find.byKey(const ValueKey('acting_consent_form_card')), findsNothing);
    });

    testWidgets('is hidden without the scope', (tester) async {
      await pump(tester, user: _acting(scopes: const ['self:read']));
      expect(
          find.byKey(const ValueKey('acting_consent_form_card')), findsNothing);
    });
  });

  group('the request itself', () {
    late List<RequestOptions> seen;

    FamilyRemoteDataSourceImpl build(ActingForSession session) {
      FlutterSecureStorage.setMockInitialValues({
        AppConstants.tokenKey: 'access-token',
      });
      seen = [];
      final dio = DioClient.createDio(actingForSession: session)
        ..httpClientAdapter = _Capturing(seen);
      return FamilyRemoteDataSourceImpl(
          dio: dio, baseUrl: AppConstants.baseUrl);
    }

    const file = ConsentEvidenceLocalFile(
      path: 'pubspec.yaml',
      name: 'ficha.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 100,
    );

    test('goes to the post-registration step-3 route WITH X-Acting-For',
        () async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1'));
      final ds = build(session);

      final receipt = await ds.uploadConsentEvidenceWhileActing(
        dependentUserId: 'ana-1',
        file: file,
      );

      expect(
        seen.single.uri.path,
        endsWith('/users/ana-1/post-registration/step-3/consent-evidence'),
      );
      expect(seen.single.method, 'POST');
      expect(seen.single.headers[AuthInterceptor.actingForHeader], 'ana-1');
      expect(seen.single.extra[AuthInterceptor.skipActingForKey], isNot(true));
      expect(receipt.evidenceId, 'ev-1');
    });

    test('the guardian-as-self route still omits the header (unchanged)',
        () async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1'));
      final ds = build(session);

      await ds.uploadConsentEvidence(dependentId: 'ana-1', file: file);

      expect(seen.single.uri.path,
          endsWith('/guardianships/me/dependents/ana-1/consent-evidence'));
      expect(seen.single.headers.containsKey(AuthInterceptor.actingForHeader),
          isFalse);
    });
  });
}

class _Capturing implements HttpClientAdapter {
  _Capturing(this.seen);

  final List<RequestOptions> seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'data': {
          'evidence_id': 'ev-1',
          'content_type': 'application/pdf',
          'size_bytes': 100,
          'uploaded_at': '2026-10-19T12:00:00.000Z',
        },
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

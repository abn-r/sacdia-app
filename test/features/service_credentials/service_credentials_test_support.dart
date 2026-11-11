import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential.dart';
import 'package:sacdia_app/features/service_credentials/domain/entities/service_credential_review.dart';
import 'package:sacdia_app/features/service_credentials/domain/repositories/service_credentials_repository.dart';
import 'package:sacdia_app/features/service_credentials/presentation/providers/service_credentials_providers.dart';
import 'package:sacdia_app/features/service_credentials/presentation/utils/service_credentials_access.dart';

import '../../support/riverpod_test_support.dart';
import '../members/members_test_support.dart' show FileAssetLoader;

export '../members/members_test_support.dart' show initLocalization;

// ── Fixtures ────────────────────────────────────────────────────────────────

ServiceCredential credential({
  String id = 'c1',
  ServiceCredentialStatus status = ServiceCredentialStatus.pendingReview,
  String? reason,
  DateTime? expiresAt,
  String? fileName = 'constancia.pdf',
  DateTime? createdAt,
}) =>
    ServiceCredential(
      id: id,
      completedAt: DateTime(2026, 3, 14),
      status: status,
      uploadStatus: ServiceCredentialUploadStatus.confirmed,
      decisionReason: reason,
      expiresAt: expiresAt,
      fileName: fileName,
      createdAt: createdAt ?? DateTime(2026, 4, 1),
    );

ReviewItem reviewItem({
  String id = 'c1',
  String name = 'Laura Méndez',
  String? club = 'Club Pionero',
  ServiceCredentialStatus status = ServiceCredentialStatus.pendingReview,
}) =>
    ReviewItem(
      id: id,
      person: ReviewPerson(userId: 'u-$id', name: name),
      clubName: club,
      completedAt: DateTime(2026, 3, 14),
      status: status,
      createdAt: DateTime(2026, 4, 1),
      reviewedAt: status == ServiceCredentialStatus.pendingReview
          ? null
          : DateTime(2026, 4, 5),
    );

ReviewPage reviewPage(
  List<ReviewItem> items, {
  int? total,
  int page = 1,
  int limit = 20,
  ReviewCounts counts =
      const ReviewCounts(pending: 2, approved: 1, rejected: 3),
}) =>
    ReviewPage(
      items: items,
      page: page,
      limit: limit,
      total: total ?? items.length,
      counts: counts,
    );

ReviewDetail reviewDetail({
  ReviewItem? item,
  String? fileUrl = 'https://files.example/c1.pdf?sig=abc',
  String? mimeType = 'application/pdf',
  String? reason,
  DateTime? expiresAt,
}) =>
    ReviewDetail(
      item: item ?? reviewItem(),
      fileUrl: fileUrl,
      mimeType: mimeType,
      decisionReason: reason,
      expiresAt: expiresAt,
    );

ConsentEvidenceLocalFile localFile({
  String name = 'constancia.pdf',
  String mime = 'application/pdf',
  int size = 2048,
  String path = '/tmp/constancia.pdf',
}) =>
    ConsentEvidenceLocalFile(
      path: path,
      name: name,
      mimeType: mime,
      sizeBytes: size,
    );

const serverFailure = ServerFailure(
  message: 'x',
  code: 409,
  errorCode: 'SERVICE_CREDENTIAL_PENDING_EXISTS',
);

// ── Fake repository ─────────────────────────────────────────────────────────

class FakeServiceCredentialsRepository implements ServiceCredentialsRepository {
  Either<Failure, List<ServiceCredential>> mine = const Right([]);
  Either<Failure, ServiceCredential> submitResult = Right(credential());
  Either<Failure, Unit> withdrawResult = const Right(unit);
  Either<Failure, Unit> approveResult = const Right(unit);
  Either<Failure, Unit> rejectResult = const Right(unit);
  Either<Failure, ReviewDetail> detailResult = Right(reviewDetail());

  /// Answers the queue per status; defaults to an empty page.
  Either<Failure, ReviewPage> Function(
    ReviewStatusFilter status,
    String search,
    int page,
  ) queue = (_, __, ___) => Right(reviewPage(const []));

  /// While set, the matching call waits for it (to look at loading states).
  Completer<void>? mineGate;
  Completer<void>? queueGate;
  Completer<void>? detailGate;

  final calls = <String>[];
  final queueRequests =
      <({ReviewStatusFilter status, String search, int page})>[];
  ConsentEvidenceLocalFile? lastFile;
  ServiceCredentialDraft? lastDraft;
  DateTime? lastExpiresAt;
  String? lastReason;

  @override
  Future<Either<Failure, List<ServiceCredential>>> getMine() async {
    calls.add('getMine');
    await mineGate?.future;
    return mine;
  }

  @override
  Future<Either<Failure, ServiceCredential>> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
    void Function(ServiceCredentialSubmitPhase phase)? onPhase,
    void Function(double progress)? onProgress,
  }) async {
    calls.add('submit');
    lastDraft = draft;
    lastFile = file;
    onPhase?.call(ServiceCredentialSubmitPhase.uploading);
    onProgress?.call(0.5);
    return submitResult;
  }

  @override
  Future<Either<Failure, Unit>> withdraw(String id) async {
    calls.add('withdraw:$id');
    return withdrawResult;
  }

  @override
  Future<Either<Failure, ReviewPage>> getReviewQueue({
    required ReviewStatusFilter status,
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    calls.add('queue:${status.apiValue}');
    queueRequests.add((status: status, search: search, page: page));
    await queueGate?.future;
    return queue(status, search, page);
  }

  @override
  Future<Either<Failure, ReviewDetail>> getReviewDetail(String id) async {
    calls.add('detail:$id');
    await detailGate?.future;
    return detailResult;
  }

  @override
  Future<Either<Failure, Unit>> approve(String id,
      {DateTime? expiresAt}) async {
    calls.add('approve:$id');
    lastExpiresAt = expiresAt;
    return approveResult;
  }

  @override
  Future<Either<Failure, Unit>> reject(String id,
      {required String reason}) async {
    calls.add('reject:$id');
    lastReason = reason;
    return rejectResult;
  }
}

// ── Users ───────────────────────────────────────────────────────────────────

class FakeAuth extends AuthNotifier {
  FakeAuth(this.user);
  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;
}

UserEntity adultUser({
  List<String> capabilities = const [],
  PrincipalKind? kind,
  SupervisionStatus? supervision,
  bool withClub = true,
}) =>
    UserEntity(
      id: 'u1',
      email: 'laura@example.com',
      name: 'Laura',
      postRegisterComplete: true,
      principal: kind == null
          ? null
          : PrincipalInfo(
              kind: kind,
              supervision: supervision == null
                  ? null
                  : SupervisionInfo(status: supervision),
            ),
      authorization: AuthorizationSnapshot(
        effectivePermissions: const [],
        capabilities: capabilities,
        activeAssignmentId: withClub ? 'a1' : null,
        clubAssignments: withClub
            ? const [
                AuthorizationGrant(
                  assignmentId: 'a1',
                  roleName: 'director',
                  clubId: 1,
                  sectionId: 10,
                  clubTypeId: 1,
                  clubTypeName: 'Aventureros',
                  status: 'active',
                ),
              ]
            : const [],
      ),
    );

const reviewerCapability = kReviewServiceCredentialsCapability;

// ── Mounting ────────────────────────────────────────────────────────────────

List<Override> credentialOverrides(
  FakeServiceCredentialsRepository repo, {
  UserEntity? user,
  bool acting = false,
}) =>
    [
      serviceCredentialsRepositoryProvider.overrideWithValue(repo),
      authNotifierProvider.overrideWith(() =>
          FakeAuth(user ?? adultUser(capabilities: [reviewerCapability]))),
      if (acting)
        actingDependentProvider
            .overrideWithValue(const ActingDependent(userId: 'minor-1')),
    ];

/// Mounts [home] at `/` inside a router that also knows the credential routes
/// (stubs that print their path, unless [routes] replaces them).
Future<GoRouter> pumpCredentialsApp(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const [],
  List<GoRoute> routes = const [],
  Size size = const Size(800, 2400),
  double textScale = 0.5,
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      for (final path in const [
        '/service-credentials',
        '/service-credentials/new',
        '/service-credentials/review',
      ])
        if (!routes.any((r) => r.path == path))
          GoRoute(
              path: path,
              builder: (_, __) => Scaffold(body: Text('route:$path'))),
      ...routes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    testProviderScope(
      overrides: overrides,
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp.router(
            theme: theme ?? AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Enough frames for the (fake) session to load and the first read to
    // start, without waiting for gated calls to finish.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  return router;
}

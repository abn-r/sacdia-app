/// Harness for the union camporee views (list and approvals): a fake
/// repository that records its calls, entity builders and a pump whose router
/// has landing routes for the screens those views push.
///
/// Reuses the user, auth fake and localization setup of
/// `supervision_view_test_harness.dart` (read only).
library;

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_union_camporees_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../coordinator/coordinator_test_harness.dart';
import 'supervision_view_test_harness.dart';

const kApproveRegistrationsCap = 'union_camporees.approve_registrations';
const kConfigureOfferingCap = 'camporee_orders.configure_offering';

const kCamporeeBoom = ServerFailure(message: 'boom');
const kCamporeeForbidden = AuthFailure(message: 'nope', code: 403);

const kHubCounts = SupervisionPendingCounts(
  territoryLevel: 'union',
  transfers: 3,
  roleAssignments: 2,
);

ServerFailure coded(String code, [String message = 'server says no']) =>
    ServerFailure(message: message, errorCode: code);

// ── Builders ────────────────────────────────────────────────────────────────

SupervisionUnionCamporee camporee(
  int id, {
  String? name,
  DateTime? start,
  DateTime? end,
  String place = '',
  bool ordersEnabled = false,
  DateTime? opensAt,
  DateTime? deadline,
}) =>
    SupervisionUnionCamporee(
      id: id,
      name: name ?? 'Camporee $id',
      startDate: start,
      endDate: end,
      place: place,
      ordersEnabled: ordersEnabled,
      ordersOpensAt: opensAt,
      ordersDeadline: deadline,
    );

SupervisionCamporeePendingClub pendingClub(
  int id, {
  String? name,
  String section = 'Conquistadores',
  String? registeredBy = 'Elena Ruiz',
  DateTime? createdAt,
}) =>
    SupervisionCamporeePendingClub(
      id: id,
      clubName: name ?? 'Club $id',
      sectionName: section,
      registeredByName: registeredBy,
      createdAt: createdAt,
    );

SupervisionCamporeePendingMember pendingMember(
  int id, {
  String? name,
  String club = 'Club Orión',
  bool insured = true,
  DateTime? createdAt,
}) =>
    SupervisionCamporeePendingMember(
      id: id,
      fullName: name ?? 'Miembro $id',
      clubName: club,
      insuranceVerified: insured,
      createdAt: createdAt,
    );

SupervisionCamporeePendingPayment pendingPayment(
  String id, {
  String? member,
  String club = 'Club Orión',
  double amount = 350,
  SupervisionCamporeePaymentType type =
      SupervisionCamporeePaymentType.inscription,
  String? reference,
  String? notes,
  String? voucherUrl,
  DateTime? paidAt,
  DateTime? createdAt,
}) =>
    SupervisionCamporeePendingPayment(
      id: id,
      memberName: member ?? 'Pagador $id',
      clubName: club,
      amount: amount,
      type: type,
      reference: reference,
      notes: notes,
      voucherUrl: voucherUrl,
      paidAt: paidAt,
      createdAt: createdAt,
    );

// ── Fake repository ─────────────────────────────────────────────────────────

enum DecisionKind { club, member, payment }

class Decision {
  Decision(this.kind, this.camporeeId, this.id, this.approve, this.reason);
  final DecisionKind kind;

  /// Null for a payment (its endpoint has no camporee id).
  final int? camporeeId;
  final String id;
  final bool approve;
  final String? reason;
}

typedef CamporeeList = Either<Failure, List<SupervisionUnionCamporee>>;
typedef CamporeeItem = Either<Failure, SupervisionUnionCamporee>;
typedef CamporeePendingResult = Either<Failure, SupervisionCamporeePending>;

class FakeCamporeesRepo implements SupervisionUnionCamporeesRepository {
  int listCalls = 0;
  final camporeeCalls = <int>[];
  final pendingCalls = <int>[];
  final decisions = <Decision>[];

  Future<CamporeeList> Function() onList = () async => Right([camporee(1)]);
  Future<CamporeeItem> Function(int id) onCamporee =
      (id) async => Right(camporee(id));
  Future<CamporeePendingResult> Function(int id) onPending =
      (_) async => const Right(SupervisionCamporeePending.empty);
  Future<Either<Failure, Unit>> Function(Decision decision) onDecide =
      (_) async => const Right(unit);

  @override
  Future<CamporeeList> getCamporees({RequestCancelToken? cancelToken}) {
    listCalls++;
    return onList();
  }

  @override
  Future<CamporeeItem> getCamporee(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) {
    camporeeCalls.add(camporeeId);
    return onCamporee(camporeeId);
  }

  @override
  Future<CamporeePendingResult> getPending(
    int camporeeId, {
    RequestCancelToken? cancelToken,
  }) {
    pendingCalls.add(camporeeId);
    return onPending(camporeeId);
  }

  @override
  Future<Either<Failure, Unit>> decideClub(
    int camporeeId,
    int camporeeClubId, {
    required bool approve,
    String? reason,
  }) {
    final d = Decision(
      DecisionKind.club,
      camporeeId,
      '$camporeeClubId',
      approve,
      reason,
    );
    decisions.add(d);
    return onDecide(d);
  }

  @override
  Future<Either<Failure, Unit>> decideMember(
    int camporeeId,
    int camporeeMemberId, {
    required bool approve,
    String? reason,
  }) {
    final d = Decision(
      DecisionKind.member,
      camporeeId,
      '$camporeeMemberId',
      approve,
      reason,
    );
    decisions.add(d);
    return onDecide(d);
  }

  @override
  Future<Either<Failure, Unit>> decidePayment(
    String paymentId, {
    required bool approve,
    String? reason,
  }) {
    final d = Decision(DecisionKind.payment, null, paymentId, approve, reason);
    decisions.add(d);
    return onDecide(d);
  }
}

// ── Pump ────────────────────────────────────────────────────────────────────

/// What a pump leaves behind for the test to inspect.
class CamporeeEnv {
  CamporeeEnv(this.repo);
  final FakeCamporeesRepo repo;

  /// Times the hub counts were fetched (a watcher wraps the home, so an
  /// invalidation shows up as a new fetch).
  int countsCalls = 0;
}

/// Pumps [home] at `/`. `/supervision/union-camporees/:id/approvals` renders
/// `approvals:<id>` and `.../orders` renders `orders:<id>`, so a push is
/// visible as text.
Future<CamporeeEnv> pumpCamporeeView(
  WidgetTester tester, {
  required Widget home,
  FakeCamporeesRepo? repo,
  List<String> capabilities = const [
    kSupervisionAppView,
    kApproveRegistrationsCap,
    kConfigureOfferingCap,
  ],
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final env = CamporeeEnv(repo ?? FakeCamporeesRepo());
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  } else {
    useTallSurface(tester);
  }
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => _CountsWatcher(env: env, child: home),
      ),
      GoRoute(
        path: '/supervision/union-camporees/:camporeeId/approvals',
        builder: (_, state) =>
            Text('approvals:${state.pathParameters['camporeeId']}'),
      ),
      GoRoute(
        path: '/supervision/union-camporees/:camporeeId/orders',
        builder: (_, state) =>
            Text('orders:${state.pathParameters['camporeeId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => FakeSupervisionAuthNotifier(
            supervisionUser(capabilities: capabilities),
          ),
        ),
        supervisionUnionCamporeesRepositoryProvider.overrideWithValue(env.repo),
        supervisionPendingCountsProvider.overrideWith((ref) async {
          env.countsCalls++;
          return kHubCounts;
        }),
      ],
      child: localized(
        (context) => MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return env;
}

class _CountsWatcher extends ConsumerWidget {
  const _CountsWatcher({required this.env, required this.child});

  final CamporeeEnv env;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(supervisionPendingCountsProvider);
    return child;
  }
}

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:sacdia_app/features/transfers/data/models/transfer_request_model.dart';
import 'package:sacdia_app/features/transfers/domain/entities/transfer_club_option.dart';
import 'package:sacdia_app/features/transfers/domain/entities/transfer_request.dart';
import 'package:sacdia_app/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:sacdia_app/features/transfers/presentation/providers/transfer_providers.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_club_picker_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_request_detail_view.dart';
import 'package:sacdia_app/features/transfers/presentation/views/transfer_requests_view.dart';

import '../family/family_test_harness.dart';

const _member = UserEntity(
  id: 'member-1',
  email: 'mateo@example.com',
  name: 'Mateo',
  postRegisterComplete: true,
  authorization: AuthorizationSnapshot(
    activeAssignmentId: 'asg-1',
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'asg-1',
        roleName: 'member',
        clubId: 1,
        clubName: 'Orión',
        sectionId: 10,
        clubTypeId: 2,
        clubTypeName: 'Conquistadores',
        localFieldId: 4,
        localFieldName: 'Asociación del Golfo',
        status: 'active',
      ),
    ],
  ),
);

class _Auth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => _member;
}

class _NoProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _Repo implements TransferRepository {
  List<TransferRequest> requests = const [];
  List<TransferClubOption> clubs = const [];
  final creates = <({int from, int to, String? reason})>[];

  @override
  Future<Either<Failure, TransferRequest>> createTransferRequest({
    required int fromSectionId,
    required int toSectionId,
    String? reason,
  }) async {
    creates.add((from: fromSectionId, to: toSectionId, reason: reason));
    return const Right(TransferRequest(
      id: 'new-1',
      toSectionId: 30,
      status: TransferStatus.pending,
    ));
  }

  @override
  Future<Either<Failure, List<TransferRequest>>> getMyTransferRequests({
    RequestCancelToken? cancelToken,
  }) async =>
      Right(requests);

  @override
  Future<Either<Failure, TransferRequest>> getTransferRequest(
    String requestId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(requests.firstWhere((r) => r.id == requestId));

  @override
  Future<Either<Failure, List<TransferClubOption>>> getDestinationClubs({
    required int localFieldId,
    required int clubTypeId,
    RequestCancelToken? cancelToken,
  }) async =>
      Right(clubs);
}

final _rejected = TransferRequest(
  id: 'dcc7e837-c2b4-4c3a-9f1e-000000000000',
  toSectionId: 20,
  toClubName: 'Diamantes',
  toSectionName: 'Conquistadores',
  fromClubName: 'Orión',
  fromSectionName: 'Conquistadores',
  status: TransferStatus.rejected,
  reviewerComment: 'El club ya completó su cupo.',
  createdAt: DateTime(2026, 11, 2, 13, 4),
  reviewedAt: DateTime(2026, 11, 3),
);

final _pending = TransferRequest(
  id: '4b1e90aa-0000-0000-0000-000000000000',
  toSectionId: 30,
  toClubName: 'Vega',
  toSectionName: 'Conquistadores',
  status: TransferStatus.pending,
  createdAt: DateTime(2026, 11, 20, 18, 40),
);

Future<void> _pump(WidgetTester tester, _Repo repo, Widget home) async {
  await pumpFamilyApp(
    tester,
    // The screen sits on top of a base page, as in the app (it pops).
    initialLocation: '/screen',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('base')),
        routes: [GoRoute(path: 'screen', builder: (_, __) => home)],
      ),
      GoRoute(
        path: '/transfer/:id',
        builder: (_, state) => Scaffold(
          body: Text('route:/transfer/${state.pathParameters['id']}'),
        ),
      ),
    ],
    overrides: [
      authNotifierProvider.overrideWith(_Auth.new),
      profileNotifierProvider.overrideWith(_NoProfile.new),
      transferRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.pumpAndSettle();
}

SacButton _button(WidgetTester tester, String key) =>
    tester.widget<SacButton>(find.byKey(ValueKey(key)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  group('model', () {
    test('reads the review comment, both clubs and the review date', () {
      final r = TransferRequestModel.fromJson({
        'transfer_request_id': 'dcc7e837-c2b4-4c3a-9f1e-000000000000',
        'to_section_id': 20,
        'status': 'rejected',
        'review_comment': 'Sin cupo',
        'reviewed_at': '2026-11-03T10:00:00.000Z',
        'created_at': '2026-11-02T13:04:00.000Z',
        'from_section': {
          'clubs': {'name': 'Orión'},
          'club_types': {'name': 'Conquistadores'},
        },
        'to_section': {
          'clubs': {'name': 'Diamantes'},
          'club_types': {'name': 'Conquistadores'},
        },
      });
      expect(r.reviewerComment, 'Sin cupo');
      expect(r.fromClubName, 'Orión');
      expect(r.toClubName, 'Diamantes');
      expect(r.reviewedAt, isNotNull);
      expect(r.folio, 'dcc7e837');
    });

    test('a club takes the member only with an active section of the type', () {
      final json = {
        'club_id': 7,
        'name': 'Vega',
        'churches': {'name': 'Iglesia Central'},
        'club_sections': [
          {'club_section_id': 70, 'active': false, 'club_type_id': 2},
          {'club_section_id': 71, 'active': true, 'club_type_id': 2},
        ],
      };
      final club = clubOptionFromJson(json, 2);
      expect(club.sectionId, 71);
      expect(club.churchName, 'Iglesia Central');
      expect(clubOptionFromJson(json, 3).isAvailable, isFalse);
    });

    test('filter: own club out, accents ignored, available clubs first', () {
      const clubs = [
        TransferClubOption(clubId: 1, name: 'Orión', sectionId: 10),
        TransferClubOption(clubId: 2, name: 'Estrella del Mar'),
        TransferClubOption(
          clubId: 3,
          name: 'Pléyades',
          churchName: 'Las Palmas',
          sectionId: 30,
        ),
      ];
      expect(
        filterDestinationClubs(clubs, query: '', excludeClubId: 1)
            .map((c) => c.clubId),
        [3, 2],
      );
      expect(
        filterDestinationClubs(clubs, query: 'pleya', excludeClubId: 1)
            .single
            .clubId,
        3,
      );
      expect(
        filterDestinationClubs(clubs, query: 'palmas').single.clubId,
        3,
      );
      expect(clubInitials('Estrella del Mar'), 'EM');
      expect(clubInitials('Vega'), 'VE');
    });
  });

  group('Cambiar de club', () {
    testWidgets('the request in review goes first and blocks a new one',
        (tester) async {
      final repo = _Repo()..requests = [_pending, _rejected];
      await _pump(tester, repo, const TransferRequestsView());

      expect(find.text('Cambiar de club'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('transfer-pending-panel')), findsOneWidget);
      expect(find.text('Orión'), findsOneWidget);
      expect(
          find.text('Conquistadores · Asociación del Golfo'), findsOneWidget);
      expect(find.text('A Diamantes'), findsOneWidget);
      expect(find.textContaining('Rechazada · 2 nov'), findsOneWidget);
      expect(find.text('Ya tienes una solicitud en revisión.'), findsOneWidget);
      expect(_button(tester, 'transfer-request-new').onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('transfer-pending-panel')));
      await tester.pumpAndSettle();
      expect(find.text('route:/transfer/${_pending.id}'), findsOneWidget);
    });

    testWidgets('without a request in review the action is enabled',
        (tester) async {
      final repo = _Repo()..requests = [_rejected];
      await _pump(tester, repo, const TransferRequestsView());

      expect(
          find.byKey(const ValueKey('transfer-pending-panel')), findsNothing);
      expect(_button(tester, 'transfer-request-new').onPressed, isNotNull);
    });
  });

  group('detail', () {
    testWidgets('a rejected request: state, comment, move and next step',
        (tester) async {
      final repo = _Repo()..requests = [_rejected];
      await _pump(
        tester,
        repo,
        TransferRequestDetailView(requestId: _rejected.id),
      );

      expect(find.text('Solicitud a Diamantes'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
      expect(find.text('El club ya completó su cupo.'), findsOneWidget);
      expect(find.text('Orión'), findsOneWidget);
      expect(find.text('Diamantes'), findsOneWidget);
      expect(find.text('dcc7e837'), findsOneWidget);
      expect(find.byKey(const ValueKey('transfer-try-other')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('transfer-state-panel')));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud de cambio de club'), findsOneWidget);
      expect(
          find.textContaining('Puedes solicitar a otro club.'), findsOneWidget);
    });
  });

  group('new request', () {
    testWidgets('choose a club, confirm with a reason and send',
        (tester) async {
      final repo = _Repo()
        ..clubs = const [
          TransferClubOption(clubId: 1, name: 'Orión', sectionId: 10),
          TransferClubOption(
            clubId: 7,
            name: 'Vega',
            churchName: 'Iglesia Central',
            sectionId: 71,
          ),
          TransferClubOption(clubId: 8, name: 'Estrella del Mar'),
        ];
      await _pump(tester, repo, const TransferClubPickerView());

      expect(find.text('Asociación del Golfo'), findsOneWidget);
      expect(find.byKey(const ValueKey('transfer-club-1')), findsNothing);
      expect(find.text('Sin sección de Conquistadores'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('transfer-club-8')));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar de Orión a Estrella del Mar'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('transfer-club-7')));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar de Orión a Vega'), findsOneWidget);
      expect(find.text('Conquistadores'), findsWidgets);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('transfer-reason')),
          matching: find.byType(EditableText),
        ),
        'Nos mudamos',
      );
      await tester.tap(find.byKey(const ValueKey('transfer-confirm-send')));
      await tester.pumpAndSettle();

      expect(repo.creates.single, (from: 10, to: 71, reason: 'Nos mudamos'));
      // Sent: back to where the picker was opened from.
      expect(find.text('base'), findsOneWidget);
    });
  });
}

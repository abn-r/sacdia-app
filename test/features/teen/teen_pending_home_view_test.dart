import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/teen/domain/entities/teen_supervision.dart';
import 'package:sacdia_app/features/teen/domain/repositories/teen_repository.dart';
import 'package:sacdia_app/features/teen/presentation/providers/teen_providers.dart';
import 'package:sacdia_app/features/teen/presentation/views/teen_pending_home_view.dart';

import '../family/family_test_harness.dart';

final _now = DateTime.utc(2026, 10, 19, 12);

class _FakeTeenRepository implements TeenRepository {
  Either<Failure, TeenSupervision> supervision = const Right(
    TeenSupervision(status: SupervisionStatus.pendingGuardian),
  );
  Either<Failure, TeenLinkCode> issued = Right(
    TeenLinkCode(
      code: '7KQ4-M9TX',
      expiresAt: DateTime.utc(2026, 10, 22, 12),
    ),
  );
  Either<Failure, void> revoked = const Right(null);

  int supervisionCalls = 0;
  int issueCalls = 0;
  final revokeCalls = <String>[];

  @override
  Future<Either<Failure, TeenSupervision>> getSupervision() async {
    supervisionCalls++;
    return supervision;
  }

  @override
  Future<Either<Failure, TeenLinkCode>> issueLinkCode() async {
    issueCalls++;
    return issued;
  }

  @override
  Future<Either<Failure, void>> revokePendingLink(String id) async {
    revokeCalls.add(id);
    return revoked;
  }
}

class _TeenAuth extends AuthNotifier {
  _TeenAuth(this.user);

  final UserEntity user;
  int signOuts = 0;
  int refreshes = 0;

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async {
    refreshes++;
    return false;
  }
}

UserEntity _teen({
  DateTime? pendingSince,
  int? daysLeft,
  List<SupervisionGuardian> guardians = const [],
}) =>
    UserEntity(
      id: 'teen-1',
      name: 'Ana',
      postRegisterComplete: true,
      principal: PrincipalInfo(
        kind: PrincipalKind.supervisedUser,
        supervision: SupervisionInfo(
          status: SupervisionStatus.pendingGuardian,
          pendingSince: pendingSince ?? _now.subtract(const Duration(days: 7)),
          guardians: guardians,
          serverDaysLeft: daysLeft,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late _FakeTeenRepository repo;
  late _TeenAuth auth;
  late List<String> shared;
  late List<String> clipboard;

  setUp(() {
    repo = _FakeTeenRepository();
    shared = [];
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, UserEntity user) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    auth = _TeenAuth(user);
    await pumpFamilyApp(
      tester,
      overrides: [
        teenRepositoryProvider.overrideWithValue(repo),
        authNotifierProvider.overrideWith(() => auth),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => TeenPendingHomeView(
            onShare: (text) async => shared.add(text),
            clock: () => _now,
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the restricted state and the days left', (tester) async {
    await pump(tester, _teen());

    expect(find.text('Falta tu tutor'), findsOneWidget);
    // 7 días corridos de 90: quedan 83.
    expect(
      find.text(
        'Te quedan 83 días para vincular a un tutor. Si no, tu cuenta se '
        'eliminará.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('one day left reads in the singular', (tester) async {
    await pump(tester, _teen(daysLeft: 1));
    expect(find.textContaining('Te queda 1 día'), findsOneWidget);
  });

  testWidgets('the last day reads as today', (tester) async {
    await pump(tester, _teen(daysLeft: 0));
    expect(find.textContaining('Hoy es el último día'), findsOneWidget);
  });

  testWidgets('the server days_left wins over the computed clock',
      (tester) async {
    await pump(tester, _teen(daysLeft: 12));
    expect(find.textContaining('Te quedan 12 días'), findsOneWidget);
  });

  testWidgets('no clock, no countdown card', (tester) async {
    repo.supervision = const Right(
      TeenSupervision(status: SupervisionStatus.pendingGuardian),
    );
    await pump(
      tester,
      const UserEntity(
        id: 'teen-1',
        principal: PrincipalInfo(
          kind: PrincipalKind.supervisedUser,
          supervision:
              SupervisionInfo(status: SupervisionStatus.pendingGuardian),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('teen_pending_countdown')), findsNothing);
  });

  group('link code', () {
    testWidgets('generate shows the code, its expiry and the share actions',
        (tester) async {
      await pump(tester, _teen());
      expect(find.byKey(const ValueKey('teen_pending_code')), findsNothing);

      await tapText(tester, 'Generar código');

      expect(repo.issueCalls, 1);
      expect(find.text('7KQ4-M9TX'), findsOneWidget);
      expect(find.textContaining('Vence el'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Generar un código nuevo'), findsOneWidget);
      expect(find.text('Generar código'), findsNothing);
    });

    testWidgets('copy puts the code on the clipboard', (tester) async {
      await pump(tester, _teen());
      await tapText(tester, 'Generar código');

      await tapText(tester, 'Copiar');

      expect(clipboard, ['7KQ4-M9TX']);
      expect(find.text('Código copiado'), findsOneWidget);
    });

    testWidgets('share sends the message with the code and the expiry',
        (tester) async {
      await pump(tester, _teen());
      await tapText(tester, 'Generar código');

      await tapText(tester, 'Compartir');

      expect(shared, hasLength(1));
      expect(shared.single, contains('7KQ4-M9TX'));
      expect(shared.single, contains('Vence el'));
    });

    testWidgets('a code that already exists server-side is not re-shown',
        (tester) async {
      repo.supervision = Right(
        TeenSupervision(
          status: SupervisionStatus.pendingGuardian,
          openLinkCode: OpenTeenLinkCode(
            expiresAt: DateTime.utc(2026, 10, 21, 9),
          ),
        ),
      );
      await pump(tester, _teen());

      expect(find.textContaining('Ya generaste un código'), findsOneWidget);
      expect(find.byKey(const ValueKey('teen_pending_code')), findsNothing);
      expect(find.text('7KQ4-M9TX'), findsNothing);
    });

    testWidgets('a business error is explained by its code, not raw text',
        (tester) async {
      repo.issued = const Left(
        ServerFailure(
          message: 'RAW SERVER TEXT',
          code: 409,
          errorCode: 'GUARDIANSHIP_ALREADY_GUARDIAN',
        ),
      );
      await pump(tester, _teen());

      await tapText(tester, 'Generar código');

      expect(find.textContaining('RAW SERVER TEXT'), findsNothing);
      expect(find.byKey(const ValueKey('teen_pending_code')), findsNothing);
      expect(find.text('Ya tienes un tutor vinculado.'), findsOneWidget);
    });

    testWidgets('the hourly limit reads as too many codes', (tester) async {
      repo.issued =
          const Left(ServerFailure(message: 'Too Many Requests', code: 429));
      await pump(tester, _teen());

      await tapText(tester, 'Generar código');

      expect(
        find.text(
            'Generaste demasiados códigos. Inténtalo de nuevo más tarde.'),
        findsOneWidget,
      );
    });
  });

  group('guardians', () {
    final pendingGuardian = TeenSupervision(
      status: SupervisionStatus.pendingGuardian,
      guardians: const [
        TeenGuardian(
          guardianshipId: 'gs-1',
          displayName: 'María Pérez',
          relationshipTypeName: 'Madre',
        ),
      ],
    );

    testWidgets('lists a pending guardian and lets the teen remove it',
        (tester) async {
      repo.supervision = Right(pendingGuardian);
      await pump(tester, _teen());

      expect(find.text('María Pérez'), findsOneWidget);
      expect(find.text('Madre'), findsOneWidget);
      expect(find.text('Pendiente de verificación'), findsOneWidget);

      await tapText(tester, 'Quitar');
      expect(find.text('¿Quitar a María Pérez?'), findsOneWidget);

      // El diálogo tiene su propio "Quitar" de confirmación.
      await tester.tap(find.text('Quitar').last);
      await tester.pump();
      await tester.pump();

      expect(repo.revokeCalls, ['gs-1']);
      expect(find.text('Vínculo quitado'), findsOneWidget);
      // Se vuelve a leer la supervisión y /auth/me (el reloj reinicia).
      expect(repo.supervisionCalls, greaterThanOrEqualTo(2));
      expect(auth.refreshes, greaterThanOrEqualTo(1));
    });

    testWidgets('cancelling the confirmation revokes nothing', (tester) async {
      repo.supervision = Right(pendingGuardian);
      await pump(tester, _teen());

      await tapText(tester, 'Quitar');
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump();

      expect(repo.revokeCalls, isEmpty);
    });

    testWidgets('a refused removal shows the mapped message', (tester) async {
      repo.supervision = Right(pendingGuardian);
      repo.revoked = const Left(
        ServerFailure(
          message: 'RAW',
          code: 404,
          errorCode: 'GUARDIANSHIP_NOT_FOUND',
        ),
      );
      await pump(tester, _teen());

      await tapText(tester, 'Quitar');
      await tester.tap(find.text('Quitar').last);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('RAW'), findsNothing);
      expect(find.text('Vínculo quitado'), findsNothing);
      expect(
        find.text('Ese vínculo ya no existe o un director ya lo verificó.'),
        findsOneWidget,
      );
    });

    testWidgets('a guardian somebody already verified has no remove button',
        (tester) async {
      repo.supervision = const Right(
        TeenSupervision(
          status: SupervisionStatus.pendingGuardian,
          guardians: [
            TeenGuardian(
              guardianshipId: 'gs-1',
              displayName: 'María Pérez',
              verified: true,
            ),
          ],
        ),
      );
      await pump(tester, _teen());

      expect(find.text('María Pérez'), findsOneWidget);
      expect(find.text('Quitar'), findsNothing);
    });

    testWidgets('when the endpoint fails, /auth/me names are shown read-only',
        (tester) async {
      repo.supervision = const Left(NetworkFailure(message: 'offline'));
      await pump(
        tester,
        _teen(
          guardians: const [
            SupervisionGuardian(
              displayName: 'María Pérez',
              relationshipTypeName: 'Madre',
            ),
          ],
        ),
      );

      expect(find.text('María Pérez'), findsOneWidget);
      // Sin id de tutoría no se puede quitar el vínculo.
      expect(find.text('Quitar'), findsNothing);
      expect(find.text('Error de conexión. Compruebe su red.'), findsOneWidget);
    });

    testWidgets('with nobody linked it says so', (tester) async {
      await pump(tester, _teen());
      expect(find.text('Aún no hay un tutor vinculado.'), findsOneWidget);
    });
  });

  testWidgets('offers only profile, password and sign out', (tester) async {
    await pump(tester, _teen());

    expect(find.text('Completar mi perfil'), findsOneWidget);
    expect(find.text('Cambiar mi contraseña'), findsOneWidget);
    // Nada de la app de miembro ni de la familia.
    expect(find.text('Mi familia'), findsNothing);
    expect(find.textContaining('club'), findsNothing);

    await tapText(tester, 'Cerrar sesión');
    expect(auth.signOuts, 1);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/camporees/presentation/views/camporee_register_member_view.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  final Future<UserEntity?> Function() loader;

  _TestAuthNotifier(this.loader);

  @override
  Future<UserEntity?> build() => loader();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('loading con dato anterior sigue bloqueado fail-closed', () {
    final previous = AsyncData(
      _registration(CamporeeSectionRegistrationStatus.registered),
    );
    final refreshing = const AsyncLoading<CamporeeSectionRegistration>()
        .copyWithPrevious(previous);

    expect(camporeeParticipantsAreEnabled(previous), isTrue);
    expect(camporeeParticipantsAreEnabled(refreshing), isFalse);
  });

  test('director activo de otra sección no autoriza la mutación', () {
    final registration = AsyncData(
      _registration(CamporeeSectionRegistrationStatus.registered),
    );
    final otherSection = AsyncData(
      _userWithActiveRole('director', sectionId: 99),
    );

    expect(
      canRegisterCamporeeParticipants(registration, otherSection),
      isFalse,
    );
  });

  for (final grantStatus in <String?>[null, 'pending', 'rejected', 'expired']) {
    test('director con active grant status $grantStatus no autoriza el alta',
        () {
      final registration = AsyncData(
        _registration(CamporeeSectionRegistrationStatus.registered),
      );
      final user = AsyncData(
        _userWithActiveRole('director', status: grantStatus),
      );

      expect(canRegisterCamporeeParticipants(registration, user), isFalse);
    });
  }

  for (final status in [
    CamporeeSectionRegistrationStatus.notEnrolled,
    CamporeeSectionRegistrationStatus.pendingApproval,
    CamporeeSectionRegistrationStatus.rejected,
    CamporeeSectionRegistrationStatus.cancelled,
    CamporeeSectionRegistrationStatus.unknown,
  ]) {
    testWidgets('$status bloquea la vista directa sin cargar participantes',
        (tester) async {
      var insuranceLoads = 0;
      var registeredIdsLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onInsuranceLoad: () => insuranceLoads += 1,
        onRegisteredIdsLoad: () => registeredIdsLoads += 1,
      );

      expect(find.text('Seleccionar miembros'), findsNothing);
      expect(find.text('Registrar 0 miembros'), findsNothing);
      expect(insuranceLoads, 0);
      expect(registeredIdsLoads, 0);
      expect(
        find.text(
          'La inscripción de participantes está bloqueada hasta que la sección esté registrada y habilitada.',
        ),
        findsOneWidget,
      );
    });
  }

  for (final role in ['deputy-director', 'secretary']) {
    testWidgets('$role no monta el formulario aunque la sección esté inscrita',
        (tester) async {
      var insuranceLoads = 0;
      var registeredIdsLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(
          CamporeeSectionRegistrationStatus.registered,
        ),
        user: _userWithActiveRole(role),
        onInsuranceLoad: () => insuranceLoads += 1,
        onRegisteredIdsLoad: () => registeredIdsLoads += 1,
      );

      expect(find.text('Seleccionar miembros'), findsNothing);
      expect(find.text('Consulta de inscripción'), findsOneWidget);
      expect(
        find.text(
          'Solo el director de la sección puede realizar la inscripción.',
        ),
        findsOneWidget,
      );
      expect(insuranceLoads, 0);
      expect(registeredIdsLoads, 0);
    });
  }

  testWidgets('un rol director histórico no reemplaza el active grant',
      (tester) async {
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      user: _userWithHistoricalDirector(),
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
  });

  testWidgets('active grant missing bloquea el formulario fail-closed',
      (tester) async {
    var insuranceLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      user: _userWithoutActiveGrant,
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () {},
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(find.text('Consulta de inscripción'), findsOneWidget);
    expect(insuranceLoads, 0);
  });

  testWidgets('auth loading bloquea formulario y fuentes de datos',
      (tester) async {
    final authCompleter = Completer<UserEntity?>();
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      authFuture: authCompleter.future,
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
  });

  testWidgets('auth error bloquea formulario y ofrece recuperación',
      (tester) async {
    var authLoads = 0;
    var insuranceLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(
        CamporeeSectionRegistrationStatus.registered,
      ),
      authLoader: () async {
        authLoads += 1;
        if (authLoads == 1) throw Exception('auth');
        return _userWithActiveRole('director');
      },
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () {},
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(find.text('No pudimos consultar la inscripción.'), findsOneWidget);
    expect(insuranceLoads, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(authLoads, 2);
    expect(find.text('Seleccionar miembros'), findsOneWidget);
  });

  testWidgets('loading bloquea fail-closed y anuncia la validación',
      (tester) async {
    final registrationCompleter = Completer<CamporeeSectionRegistration>();
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registrationFuture: registrationCompleter.future,
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Consultando inscripción de sección',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('error bloquea datos y retry vuelve a consultar el gate',
      (tester) async {
    var registrationLoads = 0;
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registrationLoader: () async {
        registrationLoads += 1;
        if (registrationLoads == 1) throw Exception('socket');
        return _registration(
          CamporeeSectionRegistrationStatus.pendingApproval,
        );
      },
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('No pudimos consultar la inscripción.'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(registrationLoads, 2);
    expect(find.text('Pendiente de aprobación'), findsOneWidget);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
  });

  for (final status in [
    CamporeeSectionRegistrationStatus.registered,
    CamporeeSectionRegistrationStatus.approved,
  ]) {
    testWidgets('$status habilita el formulario y sus fuentes de datos',
        (tester) async {
      var insuranceLoads = 0;
      var registeredIdsLoads = 0;

      await _pumpView(
        tester,
        registration: _registration(status),
        onInsuranceLoad: () => insuranceLoads += 1,
        onRegisteredIdsLoad: () => registeredIdsLoads += 1,
      );

      expect(find.text('Seleccionar miembros'), findsOneWidget);
      expect(find.text('Registrar 0 miembros'), findsOneWidget);
      expect(insuranceLoads, 1);
      expect(registeredIdsLoads, 1);
    });
  }

  testWidgets('contexto de órdenes en loading no pinta el register legacy',
      (tester) async {
    final contextCompleter = Completer<PaymentOrdersContext?>();
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(CamporeeSectionRegistrationStatus.registered),
      paymentOrdersContextFuture: contextCompleter.future,
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(find.text('Inscripción con orden de pago'), findsNothing);
    expect(find.text('Consultando el flujo de inscripción'), findsOneWidget);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Consultando el flujo de inscripción',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('contexto de órdenes con flag ON redirige a emitir orden',
      (tester) async {
    var insuranceLoads = 0;
    var registeredIdsLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(CamporeeSectionRegistrationStatus.registered),
      paymentOrdersContext: const PaymentOrdersContext(
        enabled: true,
        localFieldId: 4,
        clubSectionId: 12,
      ),
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () => registeredIdsLoads += 1,
    );

    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(find.text('Inscripción con orden de pago'), findsOneWidget);
    expect(find.text('Emitir orden de pago'), findsOneWidget);
    expect(insuranceLoads, 0);
    expect(registeredIdsLoads, 0);
  });

  testWidgets('contexto de órdenes con flag OFF conserva el flujo legacy',
      (tester) async {
    await _pumpView(
      tester,
      registration: _registration(CamporeeSectionRegistrationStatus.registered),
      paymentOrdersContext: const PaymentOrdersContext(
        enabled: false,
        localFieldId: 4,
        clubSectionId: 12,
      ),
      onInsuranceLoad: () {},
      onRegisteredIdsLoad: () {},
    );

    expect(find.text('Seleccionar miembros'), findsOneWidget);
    expect(find.text('Inscripción con orden de pago'), findsNothing);
  });

  testWidgets('error de contexto no cae a legacy y retry recarga',
      (tester) async {
    var contextLoads = 0;
    var insuranceLoads = 0;

    await _pumpView(
      tester,
      registration: _registration(CamporeeSectionRegistrationStatus.registered),
      paymentOrdersContextLoader: () async {
        contextLoads += 1;
        if (contextLoads == 1) throw Exception('socket');
        return const PaymentOrdersContext(
          enabled: true,
          localFieldId: 4,
          clubSectionId: 12,
        );
      },
      onInsuranceLoad: () => insuranceLoads += 1,
      onRegisteredIdsLoad: () {},
    );

    expect(find.text('No pudimos consultar el flujo de órdenes de pago.'),
        findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(contextLoads, 2);
    expect(find.text('Inscripción con orden de pago'), findsOneWidget);
    expect(find.text('Seleccionar miembros'), findsNothing);
    expect(insuranceLoads, 0);
  });
}

Future<void> _pumpView(
  WidgetTester tester, {
  CamporeeSectionRegistration? registration,
  Future<CamporeeSectionRegistration>? registrationFuture,
  Future<CamporeeSectionRegistration> Function()? registrationLoader,
  UserEntity? user = _defaultDirector,
  Future<UserEntity?>? authFuture,
  Future<UserEntity?> Function()? authLoader,
  PaymentOrdersContext? paymentOrdersContext,
  Future<PaymentOrdersContext?>? paymentOrdersContextFuture,
  Future<PaymentOrdersContext?> Function()? paymentOrdersContextLoader,
  required VoidCallback onInsuranceLoad,
  required VoidCallback onRegisteredIdsLoad,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(
            () {
              if (authLoader != null) return authLoader();
              if (authFuture != null) return authFuture;
              return Future.value(user);
            },
          ),
        ),
        camporeeSectionRegistrationProvider.overrideWith((ref, id) async {
          if (registrationLoader != null) return registrationLoader();
          if (registrationFuture != null) return registrationFuture;
          return registration!;
        }),
        paymentOrdersContextProvider.overrideWith((ref) async {
          if (paymentOrdersContextLoader != null) {
            return paymentOrdersContextLoader();
          }
          if (paymentOrdersContextFuture != null) {
            return paymentOrdersContextFuture;
          }
          return paymentOrdersContext;
        }),
        membersInsuranceProvider.overrideWith((ref) async {
          onInsuranceLoad();
          return const [];
        }),
        camporeeRegisteredUserIdsProvider.overrideWith((ref, id) async {
          onRegisteredIdsLoad();
          return const <String>{};
        }),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: const CamporeeRegisterMemberView(camporeeId: 41),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _defaultDirector = UserEntity(
  id: 'director-user',
  email: 'director@example.com',
  authorization: AuthorizationSnapshot(
    activeAssignmentId: 'active',
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'active',
        roleName: 'director',
        status: 'active',
        clubId: 8,
        sectionId: 12,
        clubTypeId: 2,
      ),
    ],
  ),
);

const _userWithoutActiveGrant = UserEntity(
  id: 'no-active-grant',
  email: 'missing@example.com',
  authorization: AuthorizationSnapshot(
    clubAssignments: [
      AuthorizationGrant(
        assignmentId: 'historical-director',
        roleName: 'director',
        status: 'active',
        clubId: 8,
        sectionId: 12,
        clubTypeId: 2,
      ),
    ],
  ),
);

UserEntity _userWithActiveRole(
  String role, {
  int sectionId = 12,
  String? status = 'active',
}) =>
    UserEntity(
      id: '$role-user',
      email: '$role@example.com',
      authorization: AuthorizationSnapshot(
        activeAssignmentId: 'active',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'active',
            roleName: role,
            status: status,
            clubId: 8,
            sectionId: sectionId,
            clubTypeId: 2,
          ),
        ],
      ),
    );

UserEntity _userWithHistoricalDirector() => const UserEntity(
      id: 'historical-director',
      email: 'historical@example.com',
      authorization: AuthorizationSnapshot(
        activeAssignmentId: 'active-deputy',
        clubAssignments: [
          AuthorizationGrant(
            assignmentId: 'old-director',
            roleName: 'director',
            status: 'active',
            clubId: 9,
            sectionId: 19,
            clubTypeId: 2,
          ),
          AuthorizationGrant(
            assignmentId: 'active-deputy',
            roleName: 'deputy-director',
            status: 'active',
            clubId: 8,
            sectionId: 12,
            clubTypeId: 2,
          ),
        ],
      ),
    );

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

CamporeeSectionRegistration _registration(
  CamporeeSectionRegistrationStatus status,
) {
  return CamporeeSectionRegistration(
    camporeeId: 41,
    clubId: 8,
    clubName: 'Club Orión',
    clubSectionId: 12,
    sectionName: 'Conquistadores',
    clubTypeId: 2,
    clubTypeName: 'Conquistadores',
    status: status,
    disposition: CamporeeSectionRegistrationDisposition.open,
    canEnroll: false,
  );
}

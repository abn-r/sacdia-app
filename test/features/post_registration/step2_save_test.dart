import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/utils/blood_type.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/personal_info_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_flow_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/personal_info_step_view.dart';

import '../family/family_test_harness.dart';

class _Datasource implements PersonalInfoRemoteDataSource {
  _Datasource({this.updateError});

  final Object? updateError;
  final patches = <Map<String, Object?>>[];
  int step2Calls = 0;

  @override
  Future<void> updatePersonalInfo(
    String userId, {
    String? gender,
    String? birthdate,
    bool? baptized,
    String? baptismDate,
    String? blood,
  }) async {
    patches.add({
      'gender': gender,
      'birthday': birthdate,
      'baptism': baptized,
      'baptism_date': baptismDate,
      'blood': blood,
    }..removeWhere((_, v) => v == null));
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> completeStep2(String userId) async => step2Calls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyContacts extends EmergencyContactsNotifier {
  @override
  Future<List<EmergencyContactModel>> build() async => const [];
}

final _saved = PersonalInfoSnapshot(
  gender: 'M',
  birthdate: DateTime.utc(2011, 3, 9),
  baptized: false,
  blood: 'O_POSITIVE',
);

PersonalInfoFormState _formFrom(PersonalInfoSnapshot s) =>
    PersonalInfoFormState.fromSnapshot(s);

const _teen = UserEntity(
  id: 'teen-1',
  principal: PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.pendingGuardian),
  ),
  serverMode: AccountMode.teenPending,
);

const _adult = UserEntity(
  id: 'adult-1',
  principal: PrincipalInfo(kind: PrincipalKind.user),
  serverMode: AccountMode.adult,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  group('diffPersonalInfo', () {
    test('an untouched form sends nothing', () {
      expect(diffPersonalInfo(_formFrom(_saved), _saved).isEmpty, isTrue);
    });

    test('never sends the birthday when the day is unchanged', () {
      final form = _formFrom(_saved).copyWith(
        gender: 'F',
        birthdate: DateTime(2011, 3, 9, 15), // la misma fecha, otra hora
      );
      final changes = diffPersonalInfo(form, _saved);
      expect(changes.birthdate, isNull);
      expect(changes.gender, 'F');
    });

    test('sends the birthday when it really changed', () {
      final form = _formFrom(_saved).copyWith(birthdate: DateTime(2011, 3, 10));
      expect(diffPersonalInfo(form, _saved).birthdate, isNotNull);
    });

    test('sends only the changed fields', () {
      final form = _formFrom(_saved).copyWith(
        baptized: true,
        baptismDate: DateTime(2024, 1, 20),
        bloodType: BloodType.aPos,
      );
      final changes = diffPersonalInfo(form, _saved);
      expect(changes.gender, isNull);
      expect(changes.birthdate, isNull);
      expect(changes.baptized, isTrue);
      expect(changes.baptismDate, isNotNull);
      expect(changes.blood, 'A_POSITIVE');
    });

    test('a locked birthday is never sent, even with no saved baseline', () {
      final form = PersonalInfoFormState(
        gender: 'M',
        birthdate: DateTime(2011, 3, 9),
      );
      expect(
          diffPersonalInfo(form, null, birthdayLocked: true).birthdate, isNull);
      expect(diffPersonalInfo(form, null).birthdate, isNotNull);
    });

    test('a first save with no baseline sends what was captured', () {
      final form = PersonalInfoFormState(
        gender: 'M',
        birthdate: DateTime(2011, 3, 9),
        bloodType: BloodType.oPos,
      );
      final changes = diffPersonalInfo(form, null);
      expect(changes.gender, 'M');
      expect(changes.birthdate, isNotNull);
      expect(changes.blood, 'O_POSITIVE');
      expect(changes.baptized, isFalse);
    });
  });

  group('completeStep2 (real notifiers)', () {
    Future<
        ({
          ProviderContainer c,
          _Datasource ds,
        })> setUp({
      required UserEntity user,
      Object? updateError,
      PersonalInfoFormState? form,
    }) async {
      final ds = _Datasource(updateError: updateError);
      final c = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => FakeAuthNotifier(user)),
          personalInfoDataSourceProvider.overrideWithValue(ds),
          personalInfoSnapshotProvider.overrideWith((ref) async => _saved),
        ],
      );
      addTearDown(c.dispose);
      await c.read(authNotifierProvider.future);
      await c.read(personalInfoSnapshotProvider.future);
      c.read(personalInfoFormProvider.notifier).state =
          form ?? _formFrom(_saved);
      return (c: c, ds: ds);
    }

    test('PATCH omits the unchanged birthday and still completes the step',
        () async {
      final h = await setUp(
        user: _teen,
        form: _formFrom(_saved).copyWith(bloodType: BloodType.bPos),
      );

      final result = await h.c
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: true);

      expect(result.success, isTrue);
      expect(h.ds.patches, [
        {'blood': 'B_POSITIVE'}
      ]);
      expect(h.ds.step2Calls, 1);
    });

    test('nothing changed: no PATCH at all, step still completes', () async {
      final h = await setUp(user: _adult);

      final result = await h.c
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: true);

      expect(result.success, isTrue);
      expect(h.ds.patches, isEmpty);
      expect(h.ds.step2Calls, 1);
    });

    test('a teen never sends a birthday even if the form was edited', () async {
      final h = await setUp(
        user: _teen,
        form: _formFrom(_saved).copyWith(
          birthdate: DateTime(2000, 1, 1),
          gender: 'F',
        ),
      );

      await h.c
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: true);

      expect(h.ds.patches, [
        {'gender': 'F'}
      ]);
    });

    test(
        'a failed save never reports success: the coded error is mapped, '
        'step 2 is not completed', () async {
      final h = await setUp(
        user: _teen,
        form: _formFrom(_saved).copyWith(gender: 'F'),
        updateError: ServerException(
          message: 'RAW SERVER TEXT',
          code: 422,
          errorCode: 'USER_BIRTHDAY_CHANGE_REQUIRES_GUARDIAN',
        ),
      );

      final result = await h.c
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: true);

      expect(result.success, isFalse);
      expect(result.errorCode, 'USER_BIRTHDAY_CHANGE_REQUIRES_GUARDIAN');
      expect(result.errorMessage, isNot(contains('RAW SERVER TEXT')));
      expect(h.ds.step2Calls, 0);
    });

    test('an uncoded failure shows the generic step error', () async {
      final h = await setUp(
        user: _adult,
        form: _formFrom(_saved).copyWith(gender: 'F'),
        updateError: ServerException(message: 'RAW', code: 500),
      );

      final result = await h.c
          .read(postRegistrationFlowNotifierProvider.notifier)
          .completeStep2(canReadSensitiveData: true);

      expect(result.success, isFalse);
      expect(result.errorMessage, isNot(contains('RAW')));
      expect(h.ds.step2Calls, 0);
    });
  });

  test('the guardian-only birthday error is translated in the 4 locales', () {
    const expected = {
      'es': 'Solo tu tutor puede corregir tu fecha de nacimiento.',
      'en': 'Only your guardian can correct your birthday.',
      'fr': 'Seul votre tuteur peut corriger votre date de naissance.',
      'pt-BR': 'Somente seu responsável pode corrigir sua data de nascimento.',
    };
    expected.forEach((locale, text) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final errors = json['errors'] as Map<String, dynamic>;
      expect(errors['user_birthday_change_requires_guardian'], text,
          reason: locale);
      final birth = ((json['post_registration'] as Map)['personal_info']
          as Map)['birth'] as Map;
      expect(birth['read_only_hint'], text, reason: locale);
    });
  });

  testWidgets('the mapped message reads in Spanish through userErrorMessage',
      (tester) async {
    await pumpFamilyApp(
      tester,
      overrides: const [],
      routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())],
    );
    await tester.pumpAndSettle();
    expect(
      userErrorMessage(ServerException(
        message: 'x',
        code: 422,
        errorCode: 'USER_BIRTHDAY_CHANGE_REQUIRES_GUARDIAN',
      )),
      'Solo tu tutor puede corregir tu fecha de nacimiento.',
    );
  });

  group('PersonalInfoStepView birthday', () {
    Future<void> pump(WidgetTester tester, UserEntity user) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpFamilyApp(
        tester,
        overrides: [
          authNotifierProvider.overrideWith(() => FakeAuthNotifier(user)),
          personalInfoSnapshotProvider.overrideWith((ref) async => _saved),
          emergencyContactsProvider.overrideWith(_EmptyContacts.new),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: PersonalInfoStepView(
                canReadSensitiveData: true,
                canManageAdministrativeCompletion: false,
                targetUserId: user.id,
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is read-only for a supervised teen', (tester) async {
      await pump(tester, _teen);

      expect(find.text('2011-03-09'), findsOneWidget);
      expect(
        find.text('Solo tu tutor puede corregir tu fecha de nacimiento.'),
        findsOneWidget,
      );

      // Tocar la tarjeta no abre el selector de fecha.
      await tester.tap(find.text('2011-03-09'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('stays editable for an adult', (tester) async {
      await pump(tester, _adult);

      expect(
          find.byKey(const ValueKey('birthday_read_only_hint')), findsNothing);
      await tester.tap(find.text('2011-03-09'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}

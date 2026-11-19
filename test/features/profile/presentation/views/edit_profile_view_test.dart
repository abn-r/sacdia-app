import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/profile/presentation/views/edit_profile_view.dart';

import '../../../family/family_test_harness.dart';

/// Perfil guardado que sirve el notifier falso; `updateProfile` solo registra
/// el payload y publica el perfil sin cambios (el servidor real devuelve el
/// perfil actualizado).
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this.profile, {this.saveSucceeds = true});

  final UserDetail profile;
  final bool saveSucceeds;
  final updates = <Map<String, dynamic>>[];

  @override
  Future<UserDetail?> build() async => profile;

  @override
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    updates.add(data);
    return saveSucceeds;
  }
}

class _FakePhotoNotifier extends ProfilePhotoUploadNotifier {
  final removed = <String>[];

  @override
  Future<bool> remove({required String userId}) async {
    removed.add(userId);
    return true;
  }
}

final _mateo = UserDetail(
  id: 'mateo-1',
  email: 'mateo@example.com',
  name: 'Mateo',
  paternalSurname: 'Herrera',
  gender: 'M',
  birthDate: DateTime.utc(2010, 5, 14),
  baptized: true,
  baptismDate: DateTime.utc(2022, 8, 20),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initLocalization();
    await initializeDateFormatting('es');
  });

  late _FakeProfileNotifier profileNotifier;
  late _FakePhotoNotifier photoNotifier;

  Future<void> pump(
    WidgetTester tester,
    UserDetail profile, {
    bool saveSucceeds = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    profileNotifier = _FakeProfileNotifier(profile, saveSucceeds: saveSucceeds);
    photoNotifier = _FakePhotoNotifier();
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        profileNotifierProvider.overrideWith(() => profileNotifier),
        profilePhotoUploadNotifierProvider.overrideWith(() => photoNotifier),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const EditProfileView()),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rows show the saved values and "Agregar" for empty ones',
      (tester) async {
    await pump(tester, _mateo);

    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('Herrera'), findsOneWidget);
    // Apellido materno sin valor.
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Masculino'), findsOneWidget);
    expect(
      find.text(DateFormat.yMMMd('es').format(DateTime.utc(2010, 5, 14))),
      findsOneWidget,
    );
    expect(find.text('Fecha de bautismo'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
    expect(find.text('Cambiar foto'), findsOneWidget);
  });

  testWidgets('the baptism date row only shows when baptized', (tester) async {
    await pump(
      tester,
      UserDetail(id: 'mateo-1', email: 'mateo@example.com', name: 'Mateo'),
    );

    expect(find.text('Bautismo'), findsOneWidget);
    expect(find.text('Fecha de bautismo'), findsNothing);
  });

  testWidgets(
      'editing "Nombre(s)" in its sheet saves the full payload with only the '
      'name changed', (tester) async {
    await pump(tester, _mateo);

    await tester.tap(find.text('Nombre(s)'));
    await tester.pumpAndSettle();

    // Title, helper line and editor of the sheet.
    expect(find.text('Se muestra en tu perfil y en tu credencial.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Mateo Andrés');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(profileNotifier.updates, hasLength(1));
    expect(profileNotifier.updates.single, {
      'name': 'Mateo Andrés',
      'paternal_last_name': 'Herrera',
      'maternal_last_name': '',
      'baptism': true,
      'gender': 'M',
      'birthday': DateTime.utc(2010, 5, 14).toIso8601String(),
      'baptism_date': DateTime.utc(2022, 8, 20).toIso8601String(),
    });
    // The sheet closed and the success toast is up.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Cambios guardados'), findsOneWidget);
  });

  testWidgets('the name cannot be saved empty', (tester) async {
    await pump(tester, _mateo);

    await tester.tap(find.text('Nombre(s)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El nombre es requerido'), findsOneWidget);
    expect(profileNotifier.updates, isEmpty);
  });

  testWidgets('a failed save keeps the sheet open with the error inline',
      (tester) async {
    await pump(tester, _mateo, saveSucceeds: false);

    await tester.tap(find.text('Nombre(s)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Mateo Andrés');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Error al actualizar el perfil'), findsOneWidget);
  });

  testWidgets('turning the baptism switch off saves baptism: false',
      (tester) async {
    await pump(tester, _mateo);

    await tester.tap(find.text('Bautismo'));
    await tester.pumpAndSettle();

    expect(profileNotifier.updates, hasLength(1));
    final data = profileNotifier.updates.single;
    expect(data['baptism'], false);
    expect(data.containsKey('baptism_date'), isFalse);
    expect(data['name'], 'Mateo');
  });

  testWidgets(
      'turning the switch on opens the date picker; cancelling saves nothing '
      'and leaves it off', (tester) async {
    await pump(
      tester,
      UserDetail(id: 'mateo-1', email: 'mateo@example.com', name: 'Mateo'),
    );

    await tester.tap(find.text('Bautismo'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona tu fecha de bautismo'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(profileNotifier.updates, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Fecha de bautismo'), findsNothing);
  });

  group('photo sheet', () {
    testWidgets('has no "Quitar foto" when the user has no photo',
        (tester) async {
      await pump(tester, _mateo);

      await tester.tap(find.text('Cambiar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Foto de perfil'), findsOneWidget);
      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Quitar foto'), findsNothing);
    });

    testWidgets('"Quitar foto" is last, asks to confirm and then deletes',
        (tester) async {
      await pump(
        tester,
        UserDetail(
          id: 'mateo-1',
          email: 'mateo@example.com',
          name: 'Mateo',
          avatar: 'https://cdn.example.com/avatars/mateo.jpg',
        ),
      );

      await tester.tap(find.text('Cambiar foto'));
      await tester.pumpAndSettle();

      final take = tester.getTopLeft(find.text('Tomar foto')).dy;
      final pick = tester.getTopLeft(find.text('Elegir de la galería')).dy;
      final remove = tester.getTopLeft(find.text('Quitar foto')).dy;
      expect(take < pick && pick < remove, isTrue);

      await tester.tap(find.text('Quitar foto'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quitar tu foto de perfil?'), findsOneWidget);
      expect(photoNotifier.removed, isEmpty);

      await tester.tap(find.text('Quitar foto'));
      await tester.pumpAndSettle();

      // The auth user (the fake guardian) is the one whose photo is removed.
      expect(photoNotifier.removed, [guardianUser.id]);
      expect(find.text('Foto eliminada'), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_section_registration_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('confirmación es contextual e inmutable', (tester) async {
    await _pumpSheet(tester, onConfirm: () async => false);

    expect(find.text('Club Orión'), findsOneWidget);
    expect(find.text('Conquistadores'), findsOneWidget);
    expect(find.text('Camporí Esperanza'), findsOneWidget);
    expect(find.textContaining('125'), findsOneWidget);
    expect(find.text('Inicio del Camporí'), findsOneWidget);
    expect(find.text('Fecha límite'), findsNothing);
    expect(
      find.text('Registrarás esta inscripción como director.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('club_section_id'), findsNothing);
  });

  for (final locale in const [
    Locale('en'),
    Locale('fr'),
    Locale('pt', 'BR'),
  ]) {
    testWidgets('mantiene el símbolo monetario del contrato en $locale',
        (tester) async {
      await _pumpSheet(
        tester,
        onConfirm: () async => false,
        locale: locale,
      );

      expect(find.textContaining(r'$'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
      expect(find.textContaining(r'R$'), findsNothing);
    });
  }

  testWidgets(
      'doble toque durante loading confirma una sola vez y cierra al éxito',
      (tester) async {
    final result = Completer<bool>();
    var calls = 0;
    await _pumpSheet(
      tester,
      onConfirm: () {
        calls += 1;
        return result.future;
      },
    );

    final confirm =
        find.widgetWithText(SacButton, 'Confirmar inscripción');
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CamporeeSectionRegistrationSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CamporeeSectionRegistrationSheet), findsOneWidget);

    final loadingSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Inscribiendo sección',
      ),
    );
    expect(loadingSemantics.properties.liveRegion, isTrue);

    result.complete(true);
    await tester.pumpAndSettle();

    expect(find.byType(CamporeeSectionRegistrationSheet), findsNothing);
    expect(find.text('Sección inscrita correctamente.'), findsOneWidget);
  });

  testWidgets('fallo permanece abierto y permite reintentar', (tester) async {
    var calls = 0;
    await _pumpSheet(
      tester,
      onConfirm: () async {
        calls += 1;
        return calls > 1;
      },
    );

    await tester.tap(
      find.widgetWithText(SacButton, 'Confirmar inscripción'),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos inscribir la sección.'), findsOneWidget);
    expect(find.text('Reintentar inscripción'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Reintentar inscripción'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(CamporeeSectionRegistrationSheet), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'error de submit usa texto AA y señal redundante en $brightness',
        (tester) async {
      await _pumpSheet(
        tester,
        onConfirm: () async => false,
        brightness: brightness,
      );
      await tester.tap(
        find.widgetWithText(SacButton, 'Confirmar inscripción'),
      );
      await tester.pumpAndSettle();

      final message = tester.widget<Text>(
        find.text('No pudimos inscribir la sección.'),
      );
      final errorContainer = tester.widget<Container>(
        find.byKey(const Key('camporee-registration-submit-error')),
      );
      final decoration = errorContainer.decoration! as BoxDecoration;
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'No pudimos inscribir la sección.',
        ),
      );

      expect(message.style!.color, isNot(AppColors.error));
      expect(
        _contrastRatio(message.style!.color!, decoration.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect((decoration.border! as Border).top.color, AppColors.error);
      expect(semantics.properties.liveRegion, isTrue);
    });
  }

  testWidgets('CTAs permiten dos líneas con text scaling 200%', (tester) async {
    await _pumpSheet(
      tester,
      onConfirm: () async => false,
      textScaler: const TextScaler.linear(2),
    );

    final confirmButton = find.widgetWithText(
      SacButton,
      'Confirmar inscripción',
    );
    final confirm = tester.widget<Text>(
      find.descendant(of: confirmButton, matching: find.byType(Text)),
    );
    expect(confirm.maxLines, 2);
    expect(confirm.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  test('las cuatro traducciones describen startDate como inicio, no deadline',
      () {
    const expectedLabels = {
      'es': 'Inicio del Camporí',
      'en': 'Camporee starts',
      'fr': 'Début du camporee',
      'pt-BR': 'Início do Campori',
    };
    const expectedMembersLoading = {
      'es': 'Cargando participantes inscritos',
      'en': 'Loading enrolled participants',
      'fr': 'Chargement des participants inscrits',
      'pt-BR': 'Carregando participantes inscritos',
    };

    for (final entry in expectedLabels.entries) {
      final translations = jsonDecode(
        File('assets/translations/${entry.key}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final camporees = translations['camporees'] as Map<String, dynamic>;
      final registration =
          camporees['section_registration'] as Map<String, dynamic>;
      final detail = camporees['detail'] as Map<String, dynamic>;

      expect(registration['start_date'], entry.value);
      expect(registration.containsKey('deadline'), isFalse);
      expect(camporees.containsKey('enroll_club'), isFalse);
      expect(detail['members_loading'], expectedMembersLoading[entry.key]);
    }
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<bool> Function() onConfirm,
  Locale locale = const Locale('es'),
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
        Locale('fr'),
        Locale('pt', 'BR'),
      ],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: locale,
      child: ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.darkTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: Scaffold(
                body: Builder(
                  builder: (sheetContext) => ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: sheetContext,
                      isScrollControlled: true,
                      isDismissible: false,
                      enableDrag: false,
                      builder: (_) => CamporeeSectionRegistrationSheet(
                        camporee: _camporee,
                        registration: _registration,
                        onConfirm: onConfirm,
                      ),
                    ),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

final _camporee = Camporee(
  camporeeId: 41,
  name: 'Camporí Esperanza',
  startDate: DateTime(2026, 8, 15),
  endDate: DateTime(2026, 8, 18),
  place: 'Valle Verde',
  registrationCost: 125,
  includesAdventurers: true,
  includesPathfinders: true,
  includesMasterGuides: false,
  active: true,
);

const _registration = CamporeeSectionRegistration(
  camporeeId: 41,
  clubId: 8,
  clubName: 'Club Orión',
  clubSectionId: 12,
  sectionName: 'Conquistadores',
  clubTypeId: 2,
  clubTypeName: 'Conquistadores',
  status: CamporeeSectionRegistrationStatus.notEnrolled,
  disposition: CamporeeSectionRegistrationDisposition.open,
  canEnroll: true,
);

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_event.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_agenda_now_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

CamporeeEvent _event(int id, String title, String startsAt, String endsAt,
        {String? venue}) =>
    CamporeeEvent(
      camporeeEventId: id,
      title: title,
      maxPoints: 0,
      minPoints: 0,
      dayNumber: 1,
      startsAt: startsAt,
      endsAt: endsAt,
      venueName: venue,
      displayCategory: 'logistico',
      status: 'publicado',
      participantsMode: 'all',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    ValueChanged<CamporeeEvent>? onOpen,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
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
            home: Scaffold(
              body: CamporeeAgendaNowGroup(
                events: [
                  _event(1, 'Limpieza', '09:00', '10:00',
                      venue: 'Zona de campamento'),
                  _event(2, 'Nudos', '10:30', '12:00'),
                  _event(3, 'Primeros auxilios', '10:30', '11:30'),
                ],
                startDate: DateTime(2027, 2, 10),
                clock: () => now,
                onOpenEvent: onOpen ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the activity in progress and the parallel next ones',
      (tester) async {
    CamporeeEvent? opened;
    await pump(
      tester,
      now: DateTime(2027, 2, 10, 9, 15),
      onOpen: (event) => opened = event,
    );

    expect(find.text('AHORA EN EL CAMPOREE'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Limpieza'), findsOneWidget);
    expect(find.text('Hasta las 10:00 · Zona de campamento'), findsOneWidget);
    expect(find.text('Siguiente'), findsNWidgets(2));
    expect(find.text('Nudos'), findsOneWidget);
    expect(find.text('Primeros auxilios'), findsOneWidget);
    expect(find.text('En 1 h 15 min'), findsNWidgets(2));

    await tester.tap(find.text('Limpieza'));
    expect(opened?.camporeeEventId, 1);
  });

  testWidgets('stays hidden before the camporee starts', (tester) async {
    await pump(tester, now: DateTime(2027, 2, 9, 23, 59));
    expect(find.byKey(const Key('camporee-agenda-now')), findsNothing);
  });

  testWidgets('shows from the first day, before the first activity',
      (tester) async {
    await pump(tester, now: DateTime(2027, 2, 10, 6));
    expect(find.byKey(const Key('camporee-agenda-now')), findsOneWidget);
    expect(find.text('Limpieza'), findsOneWidget);
    expect(find.text('En curso'), findsNothing);
  });

  testWidgets('hides itself once the program is over', (tester) async {
    await pump(tester, now: DateTime(2027, 2, 10, 13));
    expect(find.byKey(const Key('camporee-agenda-now')), findsNothing);
  });
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

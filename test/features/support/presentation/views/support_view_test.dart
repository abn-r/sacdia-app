import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/support/domain/entities/faq_item.dart';
import 'package:sacdia_app/features/support/domain/entities/support_report.dart';
import 'package:sacdia_app/features/support/domain/repositories/support_repository.dart';
import 'package:sacdia_app/features/support/presentation/providers/support_providers.dart';
import 'package:sacdia_app/features/support/presentation/views/faq_view.dart';
import 'package:sacdia_app/features/support/presentation/views/report_problem_view.dart';
import 'package:sacdia_app/features/support/presentation/views/support_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/riverpod_test_support.dart';

const _items = [
  FaqItem(
    id: 'password',
    category: 'account',
    question: 'Olvidé mi contraseña. ¿Cómo la recupero?',
    answer: 'Toca «¿Olvidaste tu contraseña?».',
    featured: true,
  ),
  FaqItem(
    id: 'google',
    category: 'account',
    question: '¿Puedo iniciar sesión con Google?',
    answer: 'Sí.',
  ),
  FaqItem(
    id: 'offline',
    category: 'offline',
    question: '¿La app funciona sin internet?',
    answer: 'Parte del contenido queda disponible.',
    featured: true,
  ),
];

class _Repo implements SupportRepository {
  final sent = <SupportReportDraft>[];

  @override
  Future<Either<Failure, List<FaqItem>>> loadFaq() async => const Right(_items);

  @override
  Future<Either<Failure, SupportReportResult>> submitReport(
    SupportReportDraft draft,
  ) async {
    sent.add(draft);
    return Right(
        SupportReportResult(reportId: 'r1', createdAt: DateTime(2026)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('the help screen shows the common questions and the contact',
      (tester) async {
    await _pump(tester, _Repo(), '/settings/support');

    expect(find.text('Ayuda y soporte'), findsOneWidget);
    expect(find.text('¿En qué podemos ayudarte?'), findsNothing);
    expect(
        find.text('Olvidé mi contraseña. ¿Cómo la recupero?'), findsOneWidget);
    expect(find.text('¿La app funciona sin internet?'), findsOneWidget);
    // Not featured: only in the full list.
    expect(find.text('¿Puedo iniciar sesión con Google?'), findsNothing);
    expect(find.text('Ver las 3'), findsOneWidget);
    expect(find.text('Escribir a soporte'), findsOneWidget);
    expect(find.text('Reportar un problema'), findsOneWidget);

    // An answer opens in place.
    await tester.tap(find.text('¿La app funciona sin internet?'));
    await tester.pumpAndSettle();
    expect(find.text('Parte del contenido queda disponible.'), findsOneWidget);
  });

  testWidgets('the search filters in place, without leaving the screen',
      (tester) async {
    await _pump(tester, _Repo(), '/settings/support');

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('support-search')),
        matching: find.byType(EditableText),
      ),
      'google',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 RESULTADO'), findsOneWidget);
    expect(find.text('¿Puedo iniciar sesión con Google?'), findsOneWidget);
    expect(find.text('¿La app funciona sin internet?'), findsNothing);
    expect(find.text('Escribir a soporte'), findsOneWidget);
  });

  testWidgets('the full list groups the questions under their category',
      (tester) async {
    await _pump(tester, _Repo(), '/settings/support/faq');

    expect(find.byKey(const ValueKey('faq-group-account')), findsOneWidget);
    expect(find.byKey(const ValueKey('faq-group-offline')), findsOneWidget);
    expect(find.text('CUENTA'), findsOneWidget);
    expect(find.text('SIN CONEXIÓN'), findsOneWidget);
  });

  testWidgets('a sent report shows what was sent on the same screen',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo, '/settings/support/report');

    // Device data with readable names; the report still sends the id.
    expect(find.text('iOS 26.3'), findsOneWidget);
    expect(find.text('iPhone 17 Pro'), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsOneWidget);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'La lista no carga');
    await tester.enterText(fields.at(1), 'Abro miembros y se queda en blanco.');
    await tester.tap(find.byKey(const ValueKey('support-report-submit')));
    await tester.pumpAndSettle();

    expect(repo.sent.single.title, 'La lista no carga');
    expect(repo.sent.single.deviceInfo['model'], 'iPhone18,1');
    expect(find.byKey(const ValueKey('support-report-sent')), findsOneWidget);
    expect(find.text('La lista no carga'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-report-done')), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, _Repo repo, String location) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/settings/support',
        builder: (_, __) => const SupportView(),
        routes: [
          GoRoute(path: 'faq', builder: (_, __) => const FaqView()),
          GoRoute(
            path: 'report',
            builder: (_, __) => const ReportProblemView(),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        supportRepositoryProvider.overrideWithValue(repo),
        deviceReportInfoProvider.overrideWith(
          (ref) async => {
            'platform': 'ios',
            'osVersion': '26.3',
            'model': 'iPhone18,1',
            'appVersion': '1.0.0',
            'buildNumber': '1',
          },
        ),
        deviceDisplayNameProvider.overrideWith((ref) async => 'iPhone 17 Pro'),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const _FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp.router(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

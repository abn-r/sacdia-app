import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'package:sacdia_app/features/virtual_card/presentation/views/virtual_card_view.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_qr_fullscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/riverpod_test_support.dart';

/// Reads the shipped translations, so tests assert the real Spanish copy.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      jsonDecode(
              File('$path/${locale.toLanguageTag()}.json').readAsStringSync())
          as Map<String, dynamic>;
}

VirtualCard _card({
  bool active = true,
  bool offline = false,
  String? token = 'qr-token',
  DateTime? expiresAt,
}) =>
    VirtualCard(
      userId: 'user-1',
      fullName: 'Mateo Herrera',
      roleLabel: 'Consejero',
      clubName: 'Orión',
      sectionName: 'Conquistadores',
      localFieldName: 'Asociación del Golfo',
      unionName: 'Unión Mexicana del Sur',
      ecclesiasticalYear: '2026',
      cardIdShort: '7F3A9C',
      qrToken: token,
      qrExpiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 1)),
      isActive: active,
      isOffline: offline,
      bloodType: 'O+',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(WidgetTester tester, VirtualCard card) async {
    // Wide on purpose: the test font draws every glyph as wide as it is tall.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testProviderScope(
        overrides: [
          virtualCardProvider.overrideWithValue(AsyncValue.data(card)),
          masterHonorsAvailableProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _FileAssetLoader(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: const VirtualCardView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('credentialQrStateOf', () {
    test('maps the card to what its QR can do', () {
      expect(credentialQrStateOf(_card()), CredencialQrState.ready);
      expect(credentialQrStateOf(_card(active: false)),
          CredencialQrState.suspended);
      expect(credentialQrStateOf(_card(token: null)),
          CredencialQrState.unavailable);
      expect(
        credentialQrStateOf(
          _card(expiresAt: DateTime.now().subtract(const Duration(hours: 1))),
        ),
        CredencialQrState.expired,
      );
    });
  });

  group('VirtualCardView', () {
    testWidgets('shows the card, its translated header and the data group',
        (tester) async {
      await pump(tester, _card());

      expect(find.text('CONQUISTADORES'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('Muestra este código para registrar tu asistencia'),
          findsOneWidget);
      expect(find.text('DATOS DE LA CREDENCIAL'), findsOneWidget);
      expect(find.text('Asociación del Golfo'), findsOneWidget);
      expect(find.text('Unión Mexicana del Sur'), findsOneWidget);
      // No refresh button and no big share button: share lives in the bar.
      expect(find.text('Compartir credencial'), findsNothing);
      expect(find.byTooltip('Compartir credencial'), findsOneWidget);
      expect(find.byType(SacStatePanel), findsNothing);
    });

    testWidgets('a saved copy without connection says so in a panel',
        (tester) async {
      await pump(tester, _card(offline: true));

      expect(find.byType(SacStatePanel), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
      // The card stays usable: the QR still opens.
      expect(find.text('Muestra este código para registrar tu asistencia'),
          findsOneWidget);
    });

    testWidgets('an expired code asks for a new one', (tester) async {
      await pump(
        tester,
        _card(expiresAt: DateTime.now().subtract(const Duration(hours: 1))),
      );

      expect(find.text('El código venció'), findsOneWidget);
      expect(find.text('Toca para generar un código nuevo'), findsOneWidget);
    });

    testWidgets('a suspended credential hides the code', (tester) async {
      await pump(tester, _card(active: false));

      expect(find.text('Credencial suspendida'), findsOneWidget);
      expect(find.text('Suspendida'), findsOneWidget);
      expect(find.text('El código no está disponible'), findsOneWidget);
    });

    testWidgets('tapping the QR opens it full screen', (tester) async {
      await pump(tester, _card());

      await tester.tap(find.byType(QrImageView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CredencialQrFullscreen), findsOneWidget);
      expect(find.text('Guardar imagen'), findsOneWidget);
      expect(find.textContaining('Vigente · '), findsOneWidget);
    });

    testWidgets('share opens a sheet with image and PDF', (tester) async {
      await pump(tester, _card());

      await tester.tap(find.byTooltip('Compartir credencial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Como imagen'), findsOneWidget);
      expect(find.text('Como PDF'), findsOneWidget);
    });
  });
}

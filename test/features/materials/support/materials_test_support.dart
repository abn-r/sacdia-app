import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_delivery.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_receipt_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_status.dart';
import 'package:sacdia_app/features/materials/domain/entities/order.dart';
import 'package:sacdia_app/features/materials/domain/entities/order_line.dart';
import 'package:sacdia_app/features/materials/domain/entities/material_disponibilidad.dart';
import 'package:sacdia_app/features/materials/domain/entities/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/riverpod_test_support.dart';

class FileAssetLoader extends AssetLoader {
  const FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

Future<void> initMaterialsL10n() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// Pumps [home] inside the real Spanish translations and the app theme.
Future<void> pumpMaterials(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    testProviderScope(
      overrides: overrides,
      child: EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        assetLoader: const FileAssetLoader(),
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Receipt testReceipt({
  MaterialReceiptStatus status = MaterialReceiptStatus.pendiente,
  String? rejectReason,
  DateTime? createdAt,
}) =>
    Receipt(
      id: 'r-${status.name}',
      orderId: 'order-1',
      r2Key: 'k',
      fileName: 'comprobante.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 1200,
      montoCentavos: 41000,
      status: status,
      uploadedBy: 'user-1',
      rejectReason: rejectReason,
      createdAt: createdAt ?? DateTime(2026, 11, 15),
    );

Order testOrder({
  String id = 'order-1',
  String? folio = 'MAT-2026-0142',
  MaterialStatus status = MaterialStatus.aprobada,
  int total = 41000,
  DateTime? createdAt,
  List<Receipt> receipts = const [],
  String? cancelReason,
}) =>
    Order(
      id: id,
      folioReferencia: folio,
      status: status,
      clubSectionId: 5,
      createdBy: 'user-1',
      subtotalCentavos: total,
      envioCentavos: 0,
      totalCentavos: total,
      delivery: MaterialDelivery.recoger,
      cancelReason: cancelReason,
      bankName: 'BBVA',
      bankAccountClabe: '012180001234567890',
      accountHolder: 'Campo Local Ejemplo A.C.',
      createdAt: createdAt ?? DateTime(2026, 11, 13),
      approvedAt: DateTime(2026, 11, 14),
      lines: const [
        OrderLine(
          id: 'l1',
          productId: 'p1',
          qty: 2,
          priceCentavos: 20500,
          disponibilidad: MaterialDisponibilidad.disponible,
          lineTotalCentavos: 41000,
          product: OrderLineProduct(id: 'p1', sku: 'S', title: 'Camisa caqui'),
        ),
      ],
      receipts: receipts,
    );

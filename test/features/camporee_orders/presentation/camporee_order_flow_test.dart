import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_offering.dart';
import 'package:sacdia_app/features/camporee_orders/domain/entities/camporee_order_product.dart';
import 'package:sacdia_app/features/camporee_orders/domain/repositories/camporee_orders_repository.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/providers/camporee_orders_providers.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/views/camporee_order_catalog_view.dart';
import 'package:sacdia_app/features/camporee_orders/presentation/views/camporee_order_detail_view.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_section_registration.dart';
import 'package:sacdia_app/features/camporees/presentation/providers/camporees_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_obligation.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/payment_orders_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scope = CamporeeOrdersScope(camporeeId: 41);

CamporeeOrder _order({
  required String id,
  required String folio,
  CamporeeOrderStatus status = CamporeeOrderStatus.issued,
  CamporeeOrderDistributionStatus distribution =
      CamporeeOrderDistributionStatus.notStarted,
  List<CamporeeOrderLine> lines = const [],
}) {
  return CamporeeOrder(
    orderId: id,
    localFieldId: 7,
    clubId: 3,
    clubSectionId: 12,
    localCamporeeId: 41,
    folioReference: folio,
    status: status,
    currency: 'MXN',
    totalCentavos: 15000,
    expiresAt: DateTime.utc(2026, 9, 10),
    createdAt: DateTime.utc(2026, 8, 24),
    authorizedWithoutProof: false,
    distributionStatus: distribution,
    lines: lines,
  );
}

CamporeeOrderLine _line({
  required String id,
  DateTime? deliveredAt,
}) {
  return CamporeeOrderLine(
    lineId: id,
    sequence: 1,
    camporeeMemberId: 801,
    beneficiaryUserId: 'user-1',
    beneficiaryNameSnapshot: 'Ana',
    offeringId: 'off-1',
    productId: 'prod-1',
    productTitleSnapshot: 'Playera',
    qty: 1,
    unitPriceCentavos: 15000,
    lineTotalCentavos: 15000,
    deliveredToMemberAt: deliveredAt,
  );
}

CamporeeSectionRegistration _registration({required bool enrolled}) {
  return CamporeeSectionRegistration(
    camporeeId: 41,
    clubId: 8,
    clubName: 'Club Orión',
    clubSectionId: 12,
    sectionName: 'Conquistadores',
    clubTypeId: 2,
    clubTypeName: 'Conquistadores',
    status: enrolled
        ? CamporeeSectionRegistrationStatus.registered
        : CamporeeSectionRegistrationStatus.notEnrolled,
    disposition: CamporeeSectionRegistrationDisposition.open,
    canEnroll: !enrolled,
  );
}

CamporeeOrderOfferingsCatalog _catalog({
  bool enabled = true,
  DateTime? opensAt,
  DateTime? deadline,
}) {
  return CamporeeOrderOfferingsCatalog(
    settings: CamporeeOrderSettings(
      ordersEnabled: enabled,
      ordersOpensAt: opensAt,
      ordersDeadline: deadline,
    ),
    items: const [
      CamporeeOrderOffering(
        offeringId: 'off-1',
        priceCentavos: 15000,
        active: true,
        sortOrder: 1,
        product: CamporeeOrderProduct(
          productId: 'prod-1',
          ownerScope: CamporeeOrderOwnerScope.localField,
          title: 'Playera',
          sizeScheme: CamporeeOrderSizeScheme.letter,
          active: true,
          options: [
            CamporeeOrderProductOption(
              optionId: 'opt-m',
              label: 'M',
              sortOrder: 1,
              active: true,
            ),
          ],
        ),
      ),
    ],
  );
}

PaymentObligation _obligation({
  required PaymentObligationSource source,
  required String sourceId,
  required String folio,
}) {
  return PaymentObligation(
    source: source,
    sourceId: sourceId,
    purpose: source == PaymentObligationSource.camporeeOrder
        ? PaymentObligationPurpose.camporeeMaterials
        : PaymentObligationPurpose.insurance,
    folio: folio,
    totalCentavos: 1000,
    currency: 'MXN',
    status: PaymentObligationStatus.paymentDue,
    actionRequired: PaymentObligationAction.uploadProof,
    createdAt: DateTime.utc(2026, 8, 24),
  );
}

class _FakeOrdersRepository implements CamporeeOrdersRepository {
  List<CamporeeOrderLineInput>? lastCreateLines;
  int createCalls = 0;
  Either<Failure, CamporeeOrder> createResult = Right(
    _order(id: 'ord-1', folio: 'PED20260001'),
  );

  @override
  Future<Either<Failure, CamporeeOrder>> createOrder({
    required int camporeeId,
    required List<CamporeeOrderLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
    String? idempotencyKey,
  }) async {
    createCalls += 1;
    lastCreateLines = lines;
    return createResult;
  }

  @override
  Future<Either<Failure, CamporeeOrder>> cancelOrder(String orderId) async =>
      createResult;

  @override
  Future<Either<Failure, CamporeeOrder>> deliverLineToMember({
    required String orderId,
    required String lineId,
  }) async =>
      createResult;

  @override
  Future<Either<Failure, String>> downloadOrderPdf(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) async =>
      const Right('/tmp/order.pdf');

  @override
  Future<Either<Failure, CamporeeOrderOfferingsCatalog>> getOfferings({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    RequestCancelToken? cancelToken,
  }) async =>
      Right(_catalog());

  @override
  Future<Either<Failure, CamporeeOrder>> getOrder(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) async =>
      Right(_order(id: orderId, folio: 'PED20260001'));

  @override
  Future<Either<Failure, CamporeeOrderProofDownload>> getProof(
    String orderId, {
    RequestCancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<CamporeeOrder>>> listOrders({
    int? camporeeId,
    int? unionCamporeeId,
    CamporeeOrderStatus? status,
    RequestCancelToken? cancelToken,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<PaymentObligation>>> listPendingObligations({
    int? camporeeId,
    int? unionCamporeeId,
    RequestCancelToken? cancelToken,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<CamporeeOrderProduct>>> listProducts({
    RequestCancelToken? cancelToken,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, CamporeeOrder>> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async =>
      createResult;
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${locale.toLanguageTag()}.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('resolveCamporeeOrdersCtaState', () {
    test('oculto si pedidos desactivados aunque la sección esté inscrita', () {
      expect(
        resolveCamporeeOrdersCtaState(
          sectionEnrolled: true,
          settings: const CamporeeOrderSettings(ordersEnabled: false),
        ),
        CamporeeOrdersCtaState.hidden,
      );
    });

    test('oculto si la sección no está inscrita', () {
      expect(
        resolveCamporeeOrdersCtaState(
          sectionEnrolled: false,
          settings: const CamporeeOrderSettings(ordersEnabled: true),
        ),
        CamporeeOrdersCtaState.hidden,
      );
    });

    test('abierto si settings activos y sección inscrita', () {
      expect(
        resolveCamporeeOrdersCtaState(
          sectionEnrolled: true,
          settings: const CamporeeOrderSettings(ordersEnabled: true),
        ),
        CamporeeOrdersCtaState.open,
      );
    });
  });

  group('PaymentObligation.detailPath', () {
    test('cada fuente navega a su ruta propietaria', () {
      expect(
        _obligation(
          source: PaymentObligationSource.fieldPaymentOrder,
          sourceId: 'fpo-1',
          folio: 'ORD1',
        ).detailPath,
        '/payment-orders/fpo-1',
      );
      expect(
        _obligation(
          source: PaymentObligationSource.materialOrder,
          sourceId: 'mat-1',
          folio: 'SOL1',
        ).detailPath,
        '/home/materials/order/mat-1',
      );
      expect(
        _obligation(
          source: PaymentObligationSource.camporeeOrder,
          sourceId: 'co-1',
          folio: 'PED1',
        ).detailPath,
        '/camporee-orders/co-1',
      );
    });
  });

  group('CamporeeOrderDraftNotifier', () {
    test('el payload de create no incluye montos ni ids de club', () async {
      final repository = _FakeOrdersRepository();
      final container = ProviderContainer(
        overrides: [
          camporeeOrdersRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(camporeeOrderDraftProvider(_scope).notifier);
      notifier.upsertLine(
        const CamporeeOrderDraftLine(
          camporeeMemberId: 801,
          memberName: 'Ana',
          offeringId: 'off-1',
          productTitle: 'Playera',
          optionId: 'opt-m',
          optionLabel: 'M',
          qty: 2,
          unitPriceCentavos: 15000,
        ),
      );

      final order = await notifier.submit();
      expect(order?.folioReference, 'PED20260001');
      expect(repository.createCalls, 1);
      final payload = repository.lastCreateLines!.single.toJson();
      expect(payload, {
        'camporee_member_id': 801,
        'offering_id': 'off-1',
        'option_id': 'opt-m',
        'qty': 2,
      });
      expect(
        payload.keys.toSet().intersection({
          'price',
          'total',
          'user_id',
          'club_id',
          'total_centavos',
          'unit_price_centavos',
        }),
        isEmpty,
      );
      expect(
        container.read(camporeeOrderDraftProvider(_scope)).lines,
        isEmpty,
      );
    });

    test('bloquea un segundo submit mientras isSubmitting', () async {
      final repository = _FakeOrdersRepository();
      final container = ProviderContainer(
        overrides: [
          camporeeOrdersRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final notifier =
          container.read(camporeeOrderDraftProvider(_scope).notifier);
      notifier.upsertLine(
        const CamporeeOrderDraftLine(
          camporeeMemberId: 801,
          memberName: 'Ana',
          offeringId: 'off-1',
          productTitle: 'Playera',
          qty: 1,
          unitPriceCentavos: 100,
        ),
      );

      container.read(camporeeOrderDraftProvider(_scope).notifier);
      final first = notifier.submit();
      final second = await notifier.submit();
      await first;

      expect(second, isNull);
      expect(repository.createCalls, 1);
    });
  });

  group('widgets', () {
    testWidgets('catálogo muestra loading', (tester) async {
      final pending = Completer<CamporeeOrderOfferingsCatalog>();
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) => pending.future,
          ),
          camporeeOrdersListProvider.overrideWith((ref, scope) async => []),
        ],
        child: const CamporeeOrderCatalogView(camporeeId: 41),
      );

      expect(find.byType(SacLoading), findsOneWidget);
      pending.complete(_catalog());
      await tester.pump();
    });

    testWidgets('CTA oculto cuando orders_enabled es false', (tester) async {
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeSectionRegistrationProvider.overrideWith(
            (ref, id) async => _registration(enrolled: true),
          ),
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) async => _catalog(enabled: false),
          ),
        ],
        child: const CamporeeOrdersCta(camporeeId: 41),
      );

      expect(find.byKey(const Key('camporee-orders-cta')), findsNothing);
      expect(find.text('Pedidos'), findsNothing);
    });

    testWidgets('CTA visible cuando pedidos activos y sección inscrita',
        (tester) async {
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeSectionRegistrationProvider.overrideWith(
            (ref, id) async => _registration(enrolled: true),
          ),
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) async => _catalog(),
          ),
        ],
        child: const CamporeeOrdersCta(camporeeId: 41),
      );

      expect(find.byKey(const Key('camporee-orders-cta')), findsOneWidget);
    });

    testWidgets('historial muestra dos folios independientes', (tester) async {
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) async => _catalog(),
          ),
          camporeeOrdersListProvider.overrideWith(
            (ref, scope) async => [
              _order(id: 'a', folio: 'PED20260001'),
              _order(
                id: 'b',
                folio: 'PED20260002',
                status: CamporeeOrderStatus.paid,
              ),
            ],
          ),
        ],
        child: const CamporeeOrderCatalogView(camporeeId: 41),
      );

      expect(find.text('PED20260001'), findsOneWidget);
      expect(find.text('PED20260002'), findsOneWidget);
      expect(find.byKey(const Key('camporee-order-folio-PED20260001')),
          findsOneWidget);
      expect(find.byKey(const Key('camporee-order-folio-PED20260002')),
          findsOneWidget);
    });

    testWidgets('catálogo vacío y ventana cerrada no permiten crear',
        (tester) async {
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) async => _catalog(
              deadline: DateTime.utc(2020, 1, 1),
            ),
          ),
          camporeeOrdersListProvider.overrideWith((ref, scope) async => []),
        ],
        child: const CamporeeOrderCatalogView(camporeeId: 41),
      );

      expect(find.text('Aún no hay pedidos de esta sección'), findsOneWidget);
      expect(find.textContaining('cerrado'), findsWidgets);
      final newOrder = tester.widget<SacButton>(
        find.byKey(const Key('camporee-orders-new')),
      );
      expect(newOrder.onPressed, isNull);
    });

    testWidgets('catálogo muestra error con reintento', (tester) async {
      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderOfferingsProvider.overrideWith(
            (ref, scope) async =>
                throw const ServerFailure(message: 'sin red', code: 500),
          ),
        ],
        child: const CamporeeOrderCatalogView(camporeeId: 41),
      );

      expect(find.text('sin red'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('entregar al miembro solo aparece en DELIVERED con permiso',
        (tester) async {
      final delivered = _order(
        id: 'd1',
        folio: 'PED20260009',
        status: CamporeeOrderStatus.delivered,
        distribution: CamporeeOrderDistributionStatus.partial,
        lines: [
          _line(id: 'line-a', deliveredAt: DateTime.utc(2026, 8, 25)),
          _line(id: 'line-b'),
        ],
      );

      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderDetailProvider
              .overrideWith((ref, id) async => delivered),
          canDistributeCamporeeOrdersProvider.overrideWith((ref) async => true),
        ],
        child: const CamporeeOrderDetailView(orderId: 'd1'),
      );

      expect(find.text('Entrega parcial'), findsOneWidget);
      expect(
          find.byKey(const Key('camporee-order-deliver-line-a')), findsNothing);
      expect(find.byKey(const Key('camporee-order-deliver-line-b')),
          findsOneWidget);

      await _pumpLocalized(
        tester,
        overrides: [
          camporeeOrderDetailProvider.overrideWith(
            (ref, id) async => _order(
              id: 'i1',
              folio: 'PED20260010',
              lines: [_line(id: 'line-c')],
            ),
          ),
          canDistributeCamporeeOrdersProvider.overrideWith((ref) async => true),
        ],
        child: const CamporeeOrderDetailView(orderId: 'i1'),
      );

      expect(
          find.byKey(const Key('camporee-order-deliver-line-c')), findsNothing);
    });

    testWidgets('Pagos pendientes no fusiona pedidos y navega por detailPath',
        (tester) async {
      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/payment-orders',
        routes: [
          GoRoute(
            path: '/payment-orders',
            builder: (_, __) => const PaymentOrdersView(),
          ),
          GoRoute(
            path: '/camporee-orders/:orderId',
            builder: (_, state) =>
                Text('co:${state.pathParameters['orderId']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          assetLoader: const _FileAssetLoader(),
          fallbackLocale: const Locale('es'),
          startLocale: const Locale('es'),
          child: ProviderScope(
            overrides: [
              paymentOrdersListProvider.overrideWith(
                (ref, filter) async => const <PaymentOrder>[],
              ),
              pendingPaymentObligationsProvider.overrideWith(
                (ref) async => [
                  _obligation(
                    source: PaymentObligationSource.camporeeOrder,
                    sourceId: 'co-1',
                    folio: 'PED20260001',
                  ),
                  _obligation(
                    source: PaymentObligationSource.camporeeOrder,
                    sourceId: 'co-2',
                    folio: 'PED20260002',
                  ),
                ],
              ),
            ],
            child: Builder(
              builder: (context) => MaterialApp.router(
                theme: AppTheme.lightTheme,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(disableAnimations: true),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('PED20260001'), findsOneWidget);
      expect(find.text('PED20260002'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pending-obligation-co-1')));
      await tester.pump();
      await tester.pump();

      expect(find.text('co:co-1'), findsOneWidget);
    });
  });
}

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required List<Override> overrides,
  required Widget child,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('es')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('es'),
      startLocale: const Locale('es'),
      child: ProviderScope(
        overrides: overrides,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.lightTheme,
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(disableAnimations: true),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

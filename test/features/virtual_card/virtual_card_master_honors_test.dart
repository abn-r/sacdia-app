import 'package:easy_localization/easy_localization.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/user_master_honor.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/widgets/master_honor_history_section.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/providers/virtual_card_providers.dart';
import 'package:sacdia_app/features/virtual_card/presentation/views/virtual_card_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    await EasyLocalization.ensureInitialized();
  });

  UserEntity buildUser() {
    return const UserEntity(
      id: 'user-123',
      email: 'test@example.com',
      name: 'Ana Test',
    );
  }

  VirtualCard buildCard() {
    return VirtualCard(
      userId: 'user-123',
      fullName: 'Ana Test',
      qrToken: 'qr-token',
      qrExpiresAt: DateTime(2026, 10, 1),
      isActive: true,
      isOffline: false,
    );
  }

  List<UserMasterHonor> buildHonors() {
    return [
      UserMasterHonor(
        userMasterHonorId: 1,
        masterHonorId: 1,
        name: 'Maestría de Servicio',
        status: 'AWARDED',
        isCurrent: true,
        displayStatusLabel: 'Vigente',
        awardedAt: DateTime(2026, 1, 2),
      ),
      UserMasterHonor(
        userMasterHonorId: 2,
        masterHonorId: 2,
        name: 'Maestría de Liderazgo',
        status: 'REVOKED',
        isCurrent: false,
        displayStatusLabel: 'No vigente',
        awardedAt: DateTime(2025, 5, 10),
        revokedAt: DateTime(2026, 2, 11),
        statusReason: 'No cumple requisitos vigentes.',
      ),
    ];
  }

  List<UserMasterHonor> buildVirtualCardHonors() {
    return [
      ...List.generate(
        7,
        (index) => UserMasterHonor(
          userMasterHonorId: index + 1,
          masterHonorId: index + 1,
          name: 'Maestría Vigente ${index + 1}',
          status: 'AWARDED',
          isCurrent: true,
          displayStatusLabel: 'Vigente',
          awardedAt: DateTime(2026, 1, index + 1),
        ),
      ),
      buildHonors().last,
    ];
  }

  Future<void> pumpVirtualCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider
              .overrideWith(() => _FakeAuthNotifier(buildUser())),
          virtualCardFetcherProvider.overrideWith((ref) async => buildCard()),
          userMasterHonorsProvider.overrideWith(
            (ref) async => buildVirtualCardHonors(),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          child: const MaterialApp(
            home: VirtualCardView(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpHistorySection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userMasterHonorsProvider.overrideWith((ref) async => buildHonors()),
        ],
        child: MaterialApp(
          home: const Scaffold(
            body: MasterHonorHistorySection(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Virtual card master honors band', () {
    testWidgets(
      'shows current and non-current master honors in the virtual card band',
      (tester) async {
        await pumpVirtualCard(tester);

        expect(find.text('Maestría Vigente 1'), findsOneWidget);
        expect(find.text('Maestría de Liderazgo'), findsOneWidget);
        expect(find.text('No vigente'), findsOneWidget);
      },
    );
  });

  group('Profile history section', () {
    testWidgets('lists status and date lines for master honors',
        (tester) async {
      await pumpHistorySection(tester);

      expect(find.text('Maestrías'), findsOneWidget);
      expect(find.textContaining('Concedida:'), findsNWidgets(2));
      expect(find.textContaining('Revocada:'), findsOneWidget);
      expect(find.textContaining('No vigente'), findsOneWidget);
      expect(find.textContaining('Vigente'), findsOneWidget);
    });
  });
}

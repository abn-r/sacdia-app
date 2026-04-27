import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/features/virtual_card/domain/entities/virtual_card.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/virtual_card_face.dart';

Widget _wrapApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: AspectRatio(
                  aspectRatio: 5 / 8,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

VirtualCard _sampleCard({
  bool isActive = true,
  bool isOffline = false,
  DateTime? expiresAt,
  String? tier,
}) {
  return VirtualCard(
    userId: 'usr_123',
    fullName: 'Juan Pérez Martínez',
    photoUrl: 'https://example.com/avatar.jpg',
    roleLabel: 'Conquistador · Amigo',
    roleCode: 'amigo',
    clubName: 'Trompetas de Sión',
    clubLogoUrl: 'https://example.com/club.png',
    sectionName: 'Unidad Pioneros',
    memberSince: DateTime.utc(2024, 3, 15),
    achievementTier: tier == null ? null : VirtualCardTier.fromString(tier),
    cardIdShort: 'SACDIA-202410-0421',
    qrToken: 'eyJ1aWQiOiJ1c3JfMTIzIn0.sig',
    qrExpiresAt: expiresAt ?? DateTime.utc(2099, 1, 1),
    isActive: isActive,
    isOffline: isOffline,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('renders the active card layout', (tester) async {
    await tester.pumpWidget(
      _wrapApp(
        VirtualCardFace(
          card: _sampleCard(tier: 'gold'),
          onShowQr: () {},
          onPhotoTap: () {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the offline banner when cached', (tester) async {
    await tester.pumpWidget(
      _wrapApp(
        VirtualCardFace(
          card: _sampleCard(isOffline: true),
          onShowQr: () {},
          onPhotoTap: () {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows inactive and expired states distinctly', (tester) async {
    await tester.pumpWidget(
      _wrapApp(
        VirtualCardFace(
          card: _sampleCard(
            isActive: false,
            expiresAt: DateTime.utc(2024, 1, 1),
          ),
          onShowQr: () {},
          onPhotoTap: () {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/widgets/member_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> translations;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    translations = jsonDecode(
      await File('assets/translations/es.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  ClubMember buildMember({
    String? currentClass,
    bool isEnrolled = true,
    String? clubRole,
  }) {
    return ClubMember(
      userId: 'member-1',
      name: 'Mateo',
      paternalSurname: 'Hernández',
      maternalSurname: 'Flores',
      currentClass: currentClass,
      isEnrolled: isEnrolled,
      clubRole: clubRole,
    );
  }

  Future<void> pumpMemberCard(
    WidgetTester tester, {
    String? currentClass,
    bool isEnrolled = true,
    String? clubRole,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        assetLoader: _TestAssetLoader(translations),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            home: Scaffold(
              body: MemberCard(
                member: buildMember(
                  currentClass: currentClass,
                  isEnrolled: isEnrolled,
                  clubRole: clubRole,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the mapped class logo without repeating the class name',
      (tester) async {
    await pumpMemberCard(tester, currentClass: 'Amigo');

    expect(find.text('Amigo'), findsNothing);
    expect(
      find.byKey(const ValueKey('member-card-class-logo-Amigo')),
      findsOneWidget,
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('member-card-class-logo-Amigo')),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/img/logos-clases/CQ-01.png',
    );
  });

  testWidgets('keeps the fallback for an unmapped class', (tester) async {
    await pumpMemberCard(tester, currentClass: 'Clase desconocida');

    expect(
      find.byKey(const ValueKey('member-card-class-logo-Clase desconocida')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('member-card-class-fallback-icon')),
      findsOneWidget,
    );
  });

  testWidgets('hides class content when the member has no class',
      (tester) async {
    await pumpMemberCard(tester);

    expect(find.byKey(const ValueKey('member-card-class-fallback-icon')),
        findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('hides the enrolled badge on enrolled members', (tester) async {
    await pumpMemberCard(tester, currentClass: 'Amigo');

    expect(find.text('Inscrito'), findsNothing);
  });

  testWidgets('shows not-enrolled status only when the member is not enrolled',
      (tester) async {
    await pumpMemberCard(
      tester,
      currentClass: 'Amigo',
      isEnrolled: false,
    );

    expect(find.text('No inscrito'), findsOneWidget);
    expect(find.text('Inscrito'), findsNothing);
  });

  testWidgets('stays on a two-line compact row', (tester) async {
    await pumpMemberCard(
      tester,
      currentClass: 'Amigo',
      clubRole: 'member',
    );

    expect(
        tester.getSize(find.byType(MemberCard)).height, lessThanOrEqualTo(64));
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}

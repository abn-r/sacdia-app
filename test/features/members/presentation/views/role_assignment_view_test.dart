import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/members/domain/entities/assignable_role.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/role_assignment_view.dart';
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

  const member = ClubMember(userId: 'u-1', name: 'Mateo', clubRole: 'member');
  const ctx = ClubContext(clubId: 1, sectionId: 2);

  Future<void> pump(
    WidgetTester tester,
    Future<AssignableRolesResult> Function() load,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assignableRolesProvider.overrideWith((ref, params) => load()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.lightTheme,
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: const RoleAssignmentView(member: member, clubContext: ctx),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows ineligible roles disabled with their reason',
      (tester) async {
    await pump(
      tester,
      () async => const AssignableRolesResult(roles: [
        AssignableRole(
          roleId: 'r-m',
          roleName: 'member',
          allowed: false,
          violationCode: clubRoleMemberRequiresGuideMajorSectionCode,
        ),
        AssignableRole(
          roleId: 'r-d',
          roleName: 'director',
          allowed: false,
          violationCode: clubRoleGuideMajorRequiredCode,
        ),
        AssignableRole(roleId: 'r-c', roleName: 'counselor', allowed: true),
      ]),
    );

    expect(find.text('Requiere cursar o estar investido como Guía Mayor'),
        findsOneWidget);
    expect(find.text('Un Guía Mayor no puede ser miembro en esta sección'),
        findsOneWidget);

    // Display order: director before counselor before member.
    final director = tester.getTopLeft(find.text('Director')).dy;
    final counselor = tester.getTopLeft(find.text('Consejero')).dy;
    expect(director, lessThan(counselor));

    // Tapping a blocked role does not change the selection (save stays off).
    await tester.tap(find.text('Director'));
    await tester.pump();
    expect(
      tester.widget<SacButton>(find.byType(SacButton)).onPressed,
      isNull,
    );

    // An allowed role can be selected, enabling save.
    await tester.tap(find.text('Consejero'));
    await tester.pump();
    expect(
      tester.widget<SacButton>(find.byType(SacButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('falls back to the full list when the endpoint fails',
      (tester) async {
    await pump(tester, () async => throw Exception('boom'));

    expect(find.text('Director'), findsOneWidget);
    expect(find.text('Miembro'), findsOneWidget);
    expect(find.textContaining('Requiere cursar'), findsNothing);
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

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/membership_status_banner.dart';
import 'package:sacdia_app/features/members/domain/entities/annual_continuation.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/views/annual_continuations_view.dart';
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

  testWidgets(
    'not-enrolled banner asks the directive to enroll and has no self-enroll CTA',
    (tester) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
          child: Builder(
            builder: (context) => ProviderScope(
              overrides: [
                authNotifierProvider.overrideWith(
                  () => _FakeAuthNotifier(_ghostUser()),
                ),
              ],
              child: MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const Scaffold(body: MembershipStatusBanner()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No inscrito este año. La directiva realiza tu inscripción'),
        findsOneWidget,
      );
      expect(find.text('Inscribirme'), findsNothing);
    },
  );

  testWidgets(
    'directive list shows returned GM candidate and enroll-for-period action',
    (tester) async {
      const returned = AnnualContinuation(
        userId: 'user-returned-from-cq-uuid',
        name: 'Luis Pérez Soto',
        baseSectionId: 301,
        ecclesiasticalYearId: 2026,
        annualStatus: 'not_enrolled',
        eligibility: 'eligible',
        suggestedClass: SuggestedClass(status: 'resolved', classId: 42),
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          assetLoader: _TestAssetLoader(translations),
          child: Builder(
            builder: (context) => ProviderScope(
              overrides: [
                annualContinuationsNotifierProvider.overrideWith(
                  () => _FakeContinuationsNotifier(
                    AnnualContinuationsState(
                      items: const [returned],
                      selectedIds: {'user-returned-from-cq-uuid'},
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const AnnualContinuationsView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Miembros no inscritos'), findsWidgets);
      expect(find.text('Luis Pérez Soto'), findsOneWidget);
      expect(find.text('Inscribir para 2026'), findsOneWidget);
    },
  );
}

UserEntity _ghostUser() {
  const assignmentId = 'ghost-1';
  return const UserEntity(
    id: 'user-ghost',
    email: 'ghost@example.com',
    authorization: AuthorizationSnapshot(
      activeAssignmentId: assignmentId,
      clubAssignments: [
        AuthorizationGrant(
          assignmentId: assignmentId,
          roleName: 'member',
          status: 'inactive',
          clubId: 500,
          sectionId: 301,
          clubName: 'Club Norte',
        ),
      ],
    ),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity _user;

  @override
  Future<UserEntity?> build() async => _user;
}

class _FakeContinuationsNotifier extends AnnualContinuationsNotifier {
  _FakeContinuationsNotifier(this._state);

  final AnnualContinuationsState _state;

  @override
  Future<AnnualContinuationsState> build() async => _state;
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}

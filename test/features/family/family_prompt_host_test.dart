import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_prompt_host.dart';

import 'family_test_harness.dart';

UserEntity _user({
  String id = 'guardian-1',
  bool complete = false,
  ActingForInfo? actingFor,
}) =>
    UserEntity(
      id: id,
      name: 'María',
      postRegisterComplete: complete,
      actingFor: actingFor,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);
  hostTests();

  group('shouldPromptFamily', () {
    test('asks right after the guardian finishes their own post-registration',
        () {
      expect(
        shouldPromptFamily(_user(), _user(complete: true), acting: false),
        isTrue,
      );
    });

    test('does not ask again on later launches (already complete)', () {
      expect(
        shouldPromptFamily(
          _user(complete: true),
          _user(complete: true),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask on the very first load of a complete user', () {
      expect(
        shouldPromptFamily(null, _user(complete: true), acting: false),
        isFalse,
      );
    });

    test('does not ask when a dependent finishes post-registration', () {
      expect(
        shouldPromptFamily(_user(), _user(complete: true), acting: true),
        isFalse,
      );
      expect(
        shouldPromptFamily(
          _user(id: 'ana-1'),
          _user(
            id: 'ana-1',
            complete: true,
            actingFor: const ActingForInfo(
              actorUserId: 'guardian-1',
              dependentUserId: 'ana-1',
            ),
          ),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask when the user changed', () {
      expect(
        shouldPromptFamily(
          _user(),
          _user(id: 'other', complete: true),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask on logout', () {
      expect(
        shouldPromptFamily(_user(complete: true), null, acting: false),
        isFalse,
      );
    });
  });
}

class _MutableAuth extends AuthNotifier {
  _MutableAuth(this._initial);
  final UserEntity _initial;

  @override
  Future<UserEntity?> build() async => _initial;

  void complete() => state = AsyncData(
        UserEntity(
            id: _initial.id, name: _initial.name, postRegisterComplete: true),
      );
}

void hostTests() {
  group('FamilyPromptHost', () {
    final navKey = GlobalKey<NavigatorState>();
    late _MutableAuth auth;

    Future<ProviderContainer> pumpHost(WidgetTester tester) async {
      auth = _MutableAuth(
        const UserEntity(id: 'guardian-1', name: 'María'),
      );
      final container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith(() => auth)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('es')],
            path: 'assets/translations',
            assetLoader: const FileAssetLoader(),
            fallbackLocale: const Locale('es'),
            startLocale: const Locale('es'),
            child: Builder(
              builder: (context) => MaterialApp(
                navigatorKey: navKey,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                theme: AppTheme.lightTheme,
                home: const Scaffold(body: SizedBox()),
                builder: (context, child) => FamilyPromptHost(
                  navigatorKey: navKey,
                  delay: Duration.zero,
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('asks once when the guardian finishes post-registration',
        (tester) async {
      await pumpHost(tester);

      auth.complete();
      await tester.pumpAndSettle();

      expect(find.text('¿Tienes menores a tu cargo?'), findsOneWidget);
    });

    testWidgets('the guardian-only exit suppresses the prompt exactly once',
        (tester) async {
      final container = await pumpHost(tester);
      container.read(familyPromptSuppressedProvider.notifier).state = true;

      auth.complete();
      await tester.pumpAndSettle();

      expect(find.text('¿Tienes menores a tu cargo?'), findsNothing);
      expect(container.read(familyPromptSuppressedProvider), isFalse);
    });
  });
}

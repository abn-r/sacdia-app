import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/post_registration_shell.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async {
    return UserEntity(
      id: 'user-123',
      email: 'ana@example.com',
      name: 'Ana',
      postRegisterComplete: false,
    );
  }
}

class _FakeCompletionStatusNotifier extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() async {
    return const CompletionStatus(
      isComplete: false,
      currentStep: 3,
      photoComplete: true,
      personalInfoComplete: true,
      clubSelectionComplete: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('keeps footer navigation in sync with the visible club step',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        completionStatusProvider.overrideWith(
          _FakeCompletionStatusNotifier.new,
        ),
        countriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: EasyLocalization(
          supportedLocales: const [Locale('es')],
          path: 'assets/translations',
          fallbackLocale: const Locale('es'),
          child: const MaterialApp(
            home: PostRegistrationShell(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('post_registration.club_selection.title'), findsOneWidget);
    expect(find.text('post_registration.navigation.back'), findsOneWidget);
    expect(container.read(currentStepProvider), 3);

    container.read(currentStepProvider.notifier).state = 1;
    await tester.pump();
    await tester.pump();

    expect(find.text('post_registration.club_selection.title'), findsOneWidget);
    expect(find.text('post_registration.navigation.back'), findsOneWidget);
    expect(container.read(currentStepProvider), 3);
  });
}

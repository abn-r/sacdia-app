import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/domain/repositories/post_registration_repository.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/post_registration_shell.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../family/family_test_harness.dart';

class _StatusRepository implements PostRegistrationRepository {
  Either<Failure, CompletionStatus> result;
  int calls = 0;

  _StatusRepository(this.result);

  @override
  Future<Either<Failure, CompletionStatus>> getCompletionStatus({
    RequestCancelToken? cancelToken,
  }) async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends FakeAuthNotifier {
  int signOuts = 0;

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }
}

const _notStarted = Left<Failure, CompletionStatus>(
  ServerFailure(
    message: 'Post-registration has not been started',
    code: 400,
    errorCode: 'AUTH_POST_REGISTRATION_NOT_STARTED',
  ),
);

const _fresh = Right<Failure, CompletionStatus>(
  CompletionStatus(
    isComplete: false,
    currentStep: 1,
    photoComplete: false,
    personalInfoComplete: false,
    clubSelectionComplete: false,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late _Auth auth;

  Future<void> pumpShell(
    WidgetTester tester,
    _StatusRepository repo,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    auth = _Auth();
    final prefs = await SharedPreferences.getInstance();
    await pumpFamilyApp(
      tester,
      overrides: [
        ...familyOverrides(repo: FakeFamilyRepository(), auth: auth),
        sharedPreferencesProvider.overrideWithValue(prefs),
        postRegistrationRepositoryProvider.overrideWith((ref) => repo),
      ],
      routes: [
        // En la app el shell solo se monta con la sesión ya cargada.
        GoRoute(
          path: '/',
          builder: (_, __) => Consumer(
            builder: (_, ref, __) => ref.watch(authNotifierProvider).hasValue
                ? const PostRegistrationShell()
                : const SizedBox(),
          ),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('NOT_STARTED ends in an error state, never an endless spinner',
      (tester) async {
    await pumpShell(tester, _StatusRepository(_notStarted));

    expect(find.byKey(const ValueKey('post_registration_load_error')),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Explained by its business code, not the raw server message.
    expect(find.textContaining('registro inicial'), findsOneWidget);
    expect(find.textContaining('has not been started'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('a generic failure also shows retry and sign-out',
      (tester) async {
    await pumpShell(
      tester,
      _StatusRepository(
        const Left(ServerFailure(message: 'boom', code: 500)),
      ),
    );

    expect(find.byKey(const ValueKey('post_registration_load_error')),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('Reintentar refetches and leaves the error state',
      (tester) async {
    final repo = _StatusRepository(_notStarted);
    await pumpShell(tester, repo);
    expect(repo.calls, 1);

    repo.result = _fresh;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repo.calls, 2);
    expect(find.byKey(const ValueKey('post_registration_load_error')),
        findsNothing);
    expect(find.text('Completar perfil'), findsOneWidget);
  });

  testWidgets('Cerrar sesión signs out from the error state', (tester) async {
    await pumpShell(tester, _StatusRepository(_notStarted));

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();

    expect(auth.signOuts, 1);
  });
}

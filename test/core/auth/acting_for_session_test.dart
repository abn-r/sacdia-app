import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');
  const luis = ActingDependent(userId: 'luis-1', firstName: 'Luis');

  group('ActingForSession', () {
    test('starts as the guardian: not acting, generation 0', () {
      final session = ActingForSession();
      expect(session.isActing, isFalse);
      expect(session.dependentUserId, isNull);
      expect(session.generation, 0);
    });

    test('enter sets the dependent and bumps the generation', () {
      final session = ActingForSession()..enter(ana);
      expect(session.isActing, isTrue);
      expect(session.dependentUserId, 'ana-1');
      expect(session.value?.firstName, 'Ana');
      expect(session.generation, 1);
    });

    test('switching dependents bumps the generation every time', () {
      final session = ActingForSession()
        ..enter(ana)
        ..enter(luis);
      expect(session.dependentUserId, 'luis-1');
      expect(session.generation, 2);
    });

    test('entering the same dependent still invalidates in-flight requests',
        () {
      final session = ActingForSession()
        ..enter(ana)
        ..enter(ana);
      expect(session.generation, 2);
    });

    test('exit clears the dependent and bumps the generation once', () {
      final session = ActingForSession()
        ..enter(ana)
        ..exit();
      expect(session.isActing, isFalse);
      expect(session.dependentUserId, isNull);
      expect(session.generation, 2);
    });

    test('exit while not acting is a no-op (idempotent)', () {
      final session = ActingForSession()..exit();
      expect(session.generation, 0);
      session
        ..enter(ana)
        ..exit();
      final after = session.generation;
      session.exit();
      expect(session.generation, after);
    });

    test('listeners are notified on enter, switch and exit', () {
      final session = ActingForSession();
      var notifications = 0;
      session.addListener(() => notifications++);

      session.enter(ana);
      session.enter(luis);
      session.exit();

      expect(notifications, 3);
    });

    test('it is memory-only: nothing is written to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      ActingForSession()
        ..enter(ana)
        ..enter(luis)
        ..exit();

      expect(prefs.getKeys(), isEmpty);
    });

    test('a fresh session (process restart) always starts as the guardian',
        () async {
      final first = ActingForSession()..enter(ana);
      expect(first.isActing, isTrue);

      final afterRestart = ActingForSession();
      expect(afterRestart.isActing, isFalse);
      expect(afterRestart.dependentUserId, isNull);
    });
  });

  group('actingForSessionProvider', () {
    test('is a single shared instance for the container lifetime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(actingForSessionProvider);
      final b = container.read(actingForSessionProvider);
      expect(identical(a, b), isTrue);

      a.enter(ana);
      expect(container.read(actingForSessionProvider).isActing, isTrue);
    });

    test('a new container starts as the guardian', () {
      final first = ProviderContainer();
      first.read(actingForSessionProvider).enter(ana);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(actingForSessionProvider).isActing, isFalse);
    });
  });

  test('acting_dirty key is the documented one', () {
    expect(kActingDirtyPrefsKey, 'acting_dirty');
  });
}

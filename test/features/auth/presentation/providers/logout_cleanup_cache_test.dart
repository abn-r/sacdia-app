import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/logout_cleanup.dart';
import 'package:sacdia_app/providers/storage_provider.dart';

/// Signed-out session: invalidating user providers must not hit the network.
class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

final _logoutCleanupInvoker = Provider<void Function()>((ref) {
  return () => clearUserStateOnLogout(ref);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Logout also clears the home-screen widget.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (_) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  test('logout cleanup removes only dashboard cache keys and metadata',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final userAKey =
        '${AppConstants.dashboardSummaryCacheKeyPrefix}_user-a_assignment-a';
    final userBKey =
        '${AppConstants.dashboardSummaryCacheKeyPrefix}_user-b_assignment-b';

    SharedPreferences.setMockInitialValues({
      userAKey: '{"user_name":"Ana","class_progress":50}',
      '${userAKey}_cached_at': now,
      userBKey: '{"user_name":"Luis","class_progress":50}',
      '${userBKey}_cached_at': now - 1000,
      'unrelated_pref': 'keep',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(_SignedOutAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(_logoutCleanupInvoker)();
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString(userAKey), isNull);
    expect(prefs.getInt('${userAKey}_cached_at'), isNull);
    expect(prefs.getString(userBKey), isNull);
    expect(prefs.getInt('${userBKey}_cached_at'), isNull);
    expect(prefs.getString('unrelated_pref'), equals('keep'));
  });

  test('clearUserStateOnLogout runs with empty cache without affecting prefs',
      () async {
    SharedPreferences.setMockInitialValues({
      'other_pref': 'ok',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(_SignedOutAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(_logoutCleanupInvoker)();
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString('other_pref'), equals('ok'));
  });
}

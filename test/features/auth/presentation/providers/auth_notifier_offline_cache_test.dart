import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';

class _OfflineAuthRepository extends FakeAuthRepository {
  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Left(NetworkFailure(message: 'offline'));
}

void main() {
  test('restores permissions and active club context from offline auth cache',
      () async {
    SharedPreferences.setMockInitialValues({
      'cached_post_register_complete': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = FakeSecureStorage();
    await storage.write('cached_user_id', 'user-1');
    await storage.write('cached_user_email', 'elena@example.com');
    await storage.write('cached_user_name', 'Elena');
    await storage.write('cached_active_assignment_id', 'assignment-1');
    await storage.write('cached_active_role_name', 'director');
    await storage.write('cached_active_club_type', 'Conquistadores');
    await storage.write(
      'cached_active_permissions',
      '["dashboard:read","classes:read"]',
    );
    await storage.write('cached_active_club_id', '10');
    await storage.write('cached_active_section_id', '20');
    await storage.write('cached_active_club_type_id', '1');

    final container = await buildAuthContainer(
      repo: _OfflineAuthRepository(),
      storage: storage,
      prefs: prefs,
    );

    final user = await container.read(authNotifierProvider.future);

    expect(
      user?.authorization?.effectivePermissions,
      containsAll(['dashboard:read', 'classes:read']),
    );
    expect(user?.authorization?.activeGrant?.clubId, 10);
    expect(user?.authorization?.activeGrant?.sectionId, 20);
    expect(user?.authorization?.activeGrant?.clubTypeId, 1);

    final bootstrapState = await container.read(appBootstrapProvider.future);
    expect(bootstrapState, isA<AppBootstrapReady>());
  }, timeout: const Timeout(Duration(seconds: 15)));
}

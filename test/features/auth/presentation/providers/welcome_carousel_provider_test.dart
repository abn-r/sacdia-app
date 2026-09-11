import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/features/auth/presentation/providers/welcome_carousel_provider.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('unauthenticated splash lands on welcome until the carousel is seen', () {
    expect(
      unauthenticatedSplashTarget(welcomeCarouselSeen: false),
      RouteNames.welcome,
    );
    expect(
      unauthenticatedSplashTarget(welcomeCarouselSeen: true),
      RouteNames.login,
    );
  });

  test('markSeen persists the device flag and does not reset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(welcomeCarouselSeenProvider), isFalse);

    await container.read(welcomeCarouselSeenProvider.notifier).markSeen();

    expect(container.read(welcomeCarouselSeenProvider), isTrue);
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);

    await container.read(welcomeCarouselSeenProvider.notifier).markSeen();
    expect(prefs.getBool(AppConstants.welcomeCarouselSeenKey), isTrue);
  });
}

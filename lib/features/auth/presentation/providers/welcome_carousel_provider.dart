import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/providers/storage_provider.dart';

/// Splash landing when there is no session. Device-level flag, not account.
String unauthenticatedSplashTarget({required bool welcomeCarouselSeen}) {
  return welcomeCarouselSeen ? RouteNames.login : RouteNames.welcome;
}

/// Whether this device already finished or skipped the pre-login carousel.
class WelcomeCarouselNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(AppConstants.welcomeCarouselSeenKey) ?? false;
  }

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.welcomeCarouselSeenKey, true);
  }
}

final welcomeCarouselSeenProvider =
    NotifierProvider<WelcomeCarouselNotifier, bool>(
  WelcomeCarouselNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'social_auth_client.dart';

/// Cliente de login social. Los tests lo sobreescriben con un fake.
final socialAuthClientProvider = Provider<SocialAuthClient>((ref) {
  return NativeSocialAuthClient(
    googleServerClientId: AppConstants.googleServerClientId,
    googleIosClientId: AppConstants.googleIosClientId,
  );
});

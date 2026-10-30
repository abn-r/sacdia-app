/// Single import point for the Riverpod framework types that move to
/// `package:flutter_riverpod/misc.dart` in Riverpod 3.x.
///
/// Import this file (alongside the regular `flutter_riverpod.dart` import)
/// wherever [Override], [ProviderOrFamily] or [ProviderListenable] are named,
/// so the 3.x bump only has to change the single `export` below.
library;

export 'package:flutter_riverpod/flutter_riverpod.dart'
    show Override, ProviderOrFamily, ProviderListenable;

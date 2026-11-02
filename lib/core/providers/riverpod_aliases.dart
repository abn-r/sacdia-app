/// Single import point for the Riverpod framework types that live in
/// `package:flutter_riverpod/misc.dart` since Riverpod 3.
///
/// Import this file (alongside the regular `flutter_riverpod.dart` import)
/// wherever [Override], [ProviderBase], [ProviderOrFamily] or
/// [ProviderListenable] are named,
/// so any future move of these types only has to change the single `export`
/// below.
library;

export 'package:flutter_riverpod/misc.dart'
    show Override, ProviderBase, ProviderOrFamily, ProviderListenable;

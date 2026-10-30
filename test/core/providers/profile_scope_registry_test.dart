import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honor_modal_queue_provider.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';

/// Símbolos (variable del provider o clase del notifier) que llaman a
/// `keepAlive()` en el código fuente dado, con el archivo donde aparecen.
///
/// Ignora comentarios (`//`, `///`): la documentación suele mencionar
/// `keepAlive` sin llamarlo.
Map<String, Set<String>> scanKeepAliveSymbols(Map<String, String> sources) {
  // Declaraciones de primer nivel (columna 0): clases, providers y funciones.
  final classDeclaration =
      RegExp(r'^(?:(?:abstract|base|final|sealed)\s+)*class\s+(\w+)');
  final providerDeclaration = RegExp(r'^final\s+(\w+)');
  final functionDeclaration =
      RegExp(r'^[A-Za-z_][\w<>?,. ]*?\s(\w+)\s*(?:<[^>]*>)?\(');
  final call = RegExp(r'\bkeepAlive\s*\(');
  final found = <String, Set<String>>{};

  sources.forEach((path, source) {
    String? current;
    for (final raw in source.split('\n')) {
      final declared = classDeclaration.firstMatch(raw) ??
          providerDeclaration.firstMatch(raw) ??
          functionDeclaration.firstMatch(raw);
      if (declared != null) current = declared.group(1);

      final code = raw.split('//').first;
      if (call.hasMatch(code) && current != null) {
        found.putIfAbsent(current, () => <String>{}).add(path);
      }
    }
  });
  return found;
}

/// Los `keepAlive()` encontrados que no están registrados ni en la lista de
/// catálogo.
Set<String> unregisteredKeepAlive(
  Map<String, String> sources, {
  required Set<String> registered,
  required Set<String> allowlisted,
}) =>
    scanKeepAliveSymbols(sources)
        .keys
        .where((s) => !registered.contains(s) && !allowlisted.contains(s))
        .toSet();

Map<String, String> readFeatureProviderSources() {
  final sources = <String, String>{};
  final features = Directory('lib/features');
  for (final entity in features.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final segments = entity.uri.pathSegments;
    if (segments.length < 2 || segments[segments.length - 2] != 'providers') {
      continue;
    }
    sources[entity.path] = entity.readAsStringSync();
  }
  return sources;
}

/// Clases de provider con estado de Riverpod (todo menos `Provider` simple).
const _stateKinds =
    r'(?:StateProvider|StateNotifierProvider|ChangeNotifierProvider|'
    r'FutureProvider|StreamProvider|NotifierProvider|AsyncNotifierProvider)';

/// Prefijo común de una declaración: sangría opcional (miembros, variables
/// locales) y los modificadores `static` / `late`.
const _declPrefix = r'^[ \t]*(?:(?:static|late)\s+)*final\s+';

/// Quita los comentarios de línea (`//`, `///`) de [source].
String _stripLineComments(String source) =>
    source.split('\n').map((l) => l.split('//').first).join('\n');

/// Providers SIN `autoDispose` con estado (todo menos `Provider` simple, que es
/// derivado) declarados en el código fuente dado: la variable del provider.
///
/// Entiende (S3):
///  - declaraciones partidas en varias líneas (`NotifierProvider\n  .autoDispose`);
///  - declaraciones con tipo (`final StateProvider<T> x = ...`), con el tipo
///    `AutoDispose*` descartado;
///  - miembros `static final` / `late final` y cualquier sangría;
///  - familias (`.family`), que cuentan igual que su provider base;
///  - las dos formas de declarar `autoDispose`: la de Riverpod 2.x
///    (`AutoDisposeNotifierProvider<..>(X.new)`, que nunca coincide) y la de
///    3.x (`NotifierProvider.autoDispose<..>(X.new)`, `.autoDispose.family` y
///    `.family.autoDispose`, que se descartan como `autoDispose`), tambien con
///    el tipo explicito `NotifierProvider<..>` (en 3.x ya no lleva prefijo
///    `AutoDispose`);
///  - `StateProvider` / `StateNotifierProvider` importados desde
///    `flutter_riverpod/legacy.dart` (mismo nombre de clase, mismo escaneo).
/// No confunde `final x = fooProvider;` ni `final x = ref.watch(...)` con una
/// declaración: tras `=` debe venir el constructor de un provider.
Set<String> scanNonAutoDisposeStateProviders(Iterable<String> sources) {
  // `.autoDispose`, `.autoDispose.family` (3.x) y `.family<..>.autoDispose`.
  const autoDisposeSuffix =
      r'\.\s*(?:family\s*(?:<[^;=]*?>)?\s*\.\s*)?autoDispose\b';
  final untyped = RegExp(
    '$_declPrefix(\\w+)\\s*=\\s*($_stateKinds)\\b\\s*($autoDisposeSuffix)?',
    multiLine: true,
  );
  // En 3.x el tipo explicito de un provider autoDispose es `NotifierProvider`
  // (sin prefijo `AutoDispose`): se mira tambien el lado derecho.
  final typed = RegExp(
    '$_declPrefix(AutoDispose)?($_stateKinds)(?:Family)?\\b'
    r'(?:\s*<[^;=]*?>)?\s+(\w+)\s*=(?!\s*\w+\s*'
    '$autoDisposeSuffix)',
    multiLine: true,
  );
  final found = <String>{};
  for (final source in sources) {
    final code = _stripLineComments(source);
    for (final m in untyped.allMatches(code)) {
      if (m.group(3) != null) continue;
      found.add(m.group(1)!);
    }
    for (final m in typed.allMatches(code)) {
      if (m.group(1) != null) continue;
      found.add(m.group(3)!);
    }
  }
  return found;
}

/// `Provider` simples (no `autoDispose`) cuyo cuerpo es dueño de estado mutable:
/// un caché, un notifier, un controlador, un `onDispose`... Un `Provider` simple
/// sobrevive al cambio de perfil mientras nadie invalide lo que observa, así que
/// cada uno de estos necesita una revisión explícita (S3).
///
/// Es una heurística de revisión, no una prueba: marca para que una persona
/// decida (registrar o justificar en `statefulPlainProviderAllowlist`).
Set<String> scanStatefulPlainProviders(Iterable<String> sources) {
  final plain = RegExp(
    '$_declPrefix(?:(\\w+)\\s*=\\s*Provider\\b(?!\\s*\\.\\s*autoDispose)'
    r'|Provider\b(?:\s*<[^;=]*?>)?\s+(\w+)\s*=)',
    multiLine: true,
  );
  final stateful = RegExp(
    r'ValueNotifier\s*[(<]|ChangeNotifier\b|StreamController\b|Completer\b|'
    r'\bTimer\b|\bHive\b|Box<|\bonDispose\b|\bkeepAlive\b|'
    r'CacheManager|Cache\w*\(|LinkedHashMap|HashMap|'
    r'<[^<>()]*>\s*\{\s*\}|<[^<>()]*>\s*\[\s*\]|=\s*\{\s*\}\s*;|=\s*\[\s*\]\s*;',
  );
  final found = <String>{};
  for (final source in sources) {
    final code = _stripLineComments(source);
    for (final m in plain.allMatches(code)) {
      final rest = code.substring(m.end);
      // El cuerpo llega hasta la siguiente declaración de primer nivel.
      final next = RegExp(r'\n[A-Za-z]').firstMatch(rest);
      final body = next == null ? rest : rest.substring(0, next.start);
      if (stateful.hasMatch(body)) found.add(m.group(1) ?? m.group(2)!);
    }
  }
  return found;
}

/// Los providers sin `autoDispose` con estado que no están registrados ni en la
/// lista de globales justificados.
Set<String> unregisteredNonAutoDispose(
  Iterable<String> sources, {
  required Set<String> registered,
  required Set<String> allowlisted,
}) =>
    scanNonAutoDisposeStateProviders(sources)
        .where((s) => !registered.contains(s) && !allowlisted.contains(s))
        .toSet();

/// Todo el código bajo `lib/features/**` (no solo `providers/`): hay providers
/// de estado declarados junto a su widget.
List<String> readAllFeatureSources() => [
      for (final e in Directory('lib/features').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e.readAsStringSync(),
    ];

/// Todo `lib/**` (features, core, providers, shared...): el estado que sobrevive
/// al cambio de perfil puede vivir en cualquier carpeta.
List<String> readEveryLibSource() => [
      for (final e in Directory('lib').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e.readAsStringSync(),
    ];

void main() {
  late Map<String, String> sources;

  setUpAll(() => sources = readFeatureProviderSources());

  group('profile scope registry guard (FP-52)', () {
    test('the scan sees the feature providers (sanity)', () {
      expect(sources.length, greaterThan(20));
      expect(scanKeepAliveSymbols(sources), isNotEmpty);
    });

    test('every keepAlive() provider is registered or explicitly allowlisted',
        () {
      final missing = unregisteredKeepAlive(
        sources,
        registered: profileScopedKeepAliveEntries.keys.toSet(),
        allowlisted: catalogKeepAliveAllowlist,
      );

      expect(
        missing,
        isEmpty,
        reason: 'These providers call keepAlive() but are neither in '
            'profileScopedKeepAliveEntries (invalidated on every profile '
            'switch) nor in catalogKeepAliveAllowlist (profile-independent '
            'catalogs). A cached keepAlive provider would leak one profile\'s '
            'data into the next: $missing',
      );
    });

    test('no stale registry or allowlist entries', () {
      final scanned = scanKeepAliveSymbols(sources).keys.toSet();

      expect(
        profileScopedKeepAliveEntries.keys.toSet().difference(scanned),
        isEmpty,
        reason: 'registry keys that no longer call keepAlive()',
      );
      expect(
        catalogKeepAliveAllowlist.difference(scanned),
        isEmpty,
        reason: 'allowlist entries that no longer call keepAlive()',
      );
    });

    test('a symbol is either profile-scoped or an allowlisted catalog', () {
      expect(
        profileScopedKeepAliveEntries.keys
            .toSet()
            .intersection(catalogKeepAliveAllowlist),
        isEmpty,
      );
    });

    test('the allowlist is limited to the agreed catalogs', () {
      expect(catalogKeepAliveAllowlist, {
        'configProvider',
        'categoriesProvider',
        'programsProvider',
        'RegisterCamporeeSectionNotifier',
        'CamporeeOrderDraftNotifier',
      });
    });
  });

  group('non-autoDispose state guard (FP-48, FP-52, S5)', () {
    late List<String> allSources;

    setUpAll(() => allSources = readEveryLibSource());

    test('the scan sees the known non-autoDispose providers (sanity)', () {
      expect(
        scanNonAutoDisposeStateProviders(allSources),
        containsAll(
            ['dashboardNotifierProvider', 'unreadNotificationsCountProvider']),
      );
    });

    test('every non-autoDispose state provider is registered or justified', () {
      final missing = unregisteredNonAutoDispose(
        allSources,
        registered: profileScopedStateEntries.keys.toSet(),
        allowlisted: nonAutoDisposeAllowlist.keys.toSet(),
      );

      expect(
        missing,
        isEmpty,
        reason: 'These providers are not autoDispose, so their state survives '
            'a profile switch (guardian -> Ana) and a logout. Register them in '
            'profileScopedStateEntries, or justify in nonAutoDisposeAllowlist '
            'why they do not depend on the current user: $missing',
      );
    });

    test('no stale entries in the state registry or its allowlist', () {
      final scanned = scanNonAutoDisposeStateProviders(allSources);

      expect(
        profileScopedStateEntries.keys.toSet().difference(scanned),
        isEmpty,
        reason: 'registry keys that are no longer non-autoDispose state',
      );
      expect(
        nonAutoDisposeAllowlist.keys.toSet().difference(scanned),
        isEmpty,
        reason: 'allowlist entries that are no longer non-autoDispose state',
      );
    });

    test('a provider is either registered or allowlisted, never both', () {
      expect(
        profileScopedStateEntries.keys
            .toSet()
            .intersection(nonAutoDisposeAllowlist.keys.toSet()),
        isEmpty,
      );
    });

    test('the guard covers lib/core and lib/providers too (S3)', () {
      final everything = scanNonAutoDisposeStateProviders(readEveryLibSource());

      expect(
        everything,
        containsAll([
          'themeNotifierProvider',
          'accentNotifierProvider',
          'appBootstrapProvider',
        ]),
        reason: 'device/startup providers outside lib/features must be seen',
      );
      final missing = unregisteredNonAutoDispose(
        readEveryLibSource(),
        registered: profileScopedStateEntries.keys.toSet(),
        allowlisted: nonAutoDisposeAllowlist.keys.toSet(),
      );
      expect(missing, isEmpty, reason: '$missing');
    });

    test('every allowlist entry carries a reason', () {
      for (final entry in nonAutoDisposeAllowlist.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('the user-state providers found by the verify are registered (C2, W3)',
        () {
      expect(
        profileScopedStateEntries.keys,
        containsAll([
          'honorCompletionModeOverrideProvider',
          'qrMemberTokenProvider',
          'unitsNotifierProvider',
          'masterHonorModalQueueProvider',
        ]),
      );
      expect(profileScopedProviders,
          contains(honorCompletionModeOverrideProvider));
      expect(profileScopedProviders, contains(qrMemberTokenProvider));
      expect(profileScopedProviders, contains(unitsNotifierProvider));
      expect(profileScopedProviders, contains(masterHonorModalQueueProvider));
    });

    test('the guard fails on a new unregistered StateProvider (mutation)', () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
final leakyProvider = StateProvider<Map<int, String>>((ref) => {});
final multiLineProvider = AsyncNotifierProvider
    .autoDispose<Foo, int>(Foo.new);
final goneProvider =
    NotifierProvider<Bar, int>(Bar.new);
final derivedProvider = Provider<int>((ref) => 1);
final familyProvider = FutureProvider.autoDispose.family<int, int>((r, i) async => i);
// final commentedProvider = StateProvider<int>((ref) => 0);
final typedProvider = AutoDisposeNotifierProvider<Baz, int>(Baz.new);
''',
        ],
        registered: const {},
        allowlisted: const {},
      );

      expect(missing, {'leakyProvider', 'goneProvider'});
    });

    test('S3: typed, static, late and indented declarations are seen', () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
final StateProvider<int> typedLeak = StateProvider<int>((ref) => 0);
final NotifierProvider<Foo, int>
    wrappedTypedLeak = NotifierProvider<Foo, int>(Foo.new);
final AutoDisposeStateProvider<int> typedOk =
    StateProvider.autoDispose<int>((ref) => 0);
class Holder {
  static final staticLeak = StateProvider<int>((ref) => 0);
  late final lateLeak = NotifierProvider<Foo, int>(Foo.new);
  static final StreamProvider<int> staticTypedLeak = StreamProvider<int>((r) => s);
}
void f(WidgetRef ref) {
  final indentedLeak = FutureProvider<int>((ref) async => 1);
  final notAProvider = authNotifierProvider;
  final alsoNot = ref.watch(unitsNotifierProvider);
}
''',
        ],
        registered: const {},
        allowlisted: const {},
      );

      expect(missing, {
        'typedLeak',
        'wrappedTypedLeak',
        'staticLeak',
        'lateLeak',
        'staticTypedLeak',
        'indentedLeak',
      });
    });

    test('an allowlisted or registered provider passes the guard', () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
final aProvider = StateProvider<int>((ref) => 1);
final bProvider = FutureProvider<int>((ref) async => 1);
''',
        ],
        registered: const {'aProvider'},
        allowlisted: const {'bProvider'},
      );

      expect(missing, isEmpty);
    });

    // --- Riverpod 3 declaration forms (change riverpod-3-migration, R2) -----
    // Hoy corren sobre 2.6 (inertes: solo el texto fuente cambia); son las
    // formas que apareceran tras el bump y el guard debe seguir vigilando.

    test('S2.3: the new-form non-autoDispose providers are reported (mutation)',
        () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final newLeakProvider = NotifierProvider<NewLeak, int>(NewLeak.new);
final newAsyncLeakProvider =
    AsyncNotifierProvider<NewAsyncLeak, int>(NewAsyncLeak.new);
final newFamilyLeakProvider =
    NotifierProvider.family<NewFamilyLeak, int, String>(NewFamilyLeak.new);
final legacyStateLeak = StateProvider<int>((ref) => 0);
final legacyNotifierLeak =
    StateNotifierProvider<LegacyNotifier, int>((ref) => LegacyNotifier());
final StateProvider<int> legacyTypedLeak = StateProvider<int>((ref) => 0);
''',
        ],
        registered: const {},
        allowlisted: const {},
      );

      expect(missing, {
        'newLeakProvider',
        'newAsyncLeakProvider',
        'newFamilyLeakProvider',
        'legacyStateLeak',
        'legacyNotifierLeak',
        'legacyTypedLeak',
      });
    });

    test('S2.3: the new autoDispose forms are NOT reported as non-autoDispose',
        () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
final ctorProvider = NotifierProvider.autoDispose<Ok, int>(Ok.new);
final multiLineProvider = AsyncNotifierProvider
    .autoDispose<OkAsync, int>(OkAsync.new);
final familyProvider =
    NotifierProvider.autoDispose.family<OkFam, int, String>(OkFam.new);
final asyncFamilyProvider = AsyncNotifierProvider
    .autoDispose
    .family<OkAsyncFam, int, String>(OkAsyncFam.new);
final reversedFamilyProvider =
    NotifierProvider.family.autoDispose<OkRev, int, String>(OkRev.new);
final NotifierProvider<Ok, int> typedProvider =
    NotifierProvider.autoDispose<Ok, int>(Ok.new);
final legacyAutoProvider = StateProvider.autoDispose<int>((ref) => 0);
final FutureProvider<int> typedFutureProvider =
    FutureProvider.autoDispose<int>((ref) async => 1);
''',
        ],
        registered: const {},
        allowlisted: const {},
      );

      expect(missing, isEmpty);
    });

    test('S2.3: old and new forms side by side (only the leaks are reported)',
        () {
      final missing = unregisteredNonAutoDispose(
        [
          '''
final oldCtorProvider = AutoDisposeNotifierProvider<Old, int>(Old.new);
final oldAutoProvider = NotifierProvider.autoDispose<Old2, int>(Old2.new);
final newAutoProvider = NotifierProvider.autoDispose<New, int>(New.new);
final oldLeakProvider = NotifierProvider<OldLeak, int>(OldLeak.new);
final newLeakProvider = AsyncNotifierProvider<NewLeak, int>(NewLeak.new);
''',
        ],
        registered: const {},
        allowlisted: const {},
      );

      expect(missing, {'oldLeakProvider', 'newLeakProvider'});
    });
  });

  group('plain Provider holding mutable state (S3)', () {
    test('a Provider that owns state is reported, a pure factory is not', () {
      final found = scanStatefulPlainProviders([
        '''
final cachingProvider = Provider<Foo>((ref) {
  final memo = <String, int>{};
  return Foo(memo);
});
final notifierHolderProvider = Provider<Bar>((ref) {
  final session = BarSession();
  ref.onDispose(session.dispose);
  return session;
});
final typedHolder = Provider<ValueNotifier<int>>((ref) => ValueNotifier(0));
final StreamControllerProvider = Provider<S>((ref) => S(StreamController<int>()));
final repoProvider = Provider<Repo>((ref) {
  return RepoImpl(ref.watch(dioProvider));
});
final autoProvider = Provider.autoDispose<Foo>((ref) {
  final memo = <String, int>{};
  return Foo(memo);
});
// final commentedProvider = Provider<Foo>((ref) => ValueNotifier(0));
''',
      ]);

      expect(found, {
        'cachingProvider',
        'notifierHolderProvider',
        'typedHolder',
        'StreamControllerProvider',
      });
    });

    test('every stateful plain Provider in lib is registered or reviewed', () {
      final missing = scanStatefulPlainProviders(readEveryLibSource())
          .where((s) =>
              !profileScopedStateEntries.containsKey(s) &&
              !statefulPlainProviderAllowlist.containsKey(s))
          .toSet();

      expect(
        missing,
        isEmpty,
        reason: 'These plain Providers own mutable state (a cache, a notifier, '
            'a controller...). Plain Providers survive a profile switch '
            'unless something they watch is invalidated. Register them in '
            'profileScopedStateEntries or justify them in '
            'statefulPlainProviderAllowlist: $missing',
      );
    });

    test('no stale entries in the stateful plain Provider allowlist', () {
      final scanned = scanStatefulPlainProviders(readEveryLibSource());

      expect(
        statefulPlainProviderAllowlist.keys.toSet().difference(scanned),
        isEmpty,
      );
      for (final entry in statefulPlainProviderAllowlist.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });
  });

  group('profileScopedProviders', () {
    test('contains the user-specific providers used on logout', () {
      for (final provider in userSpecificProviders) {
        expect(profileScopedProviders, contains(provider));
      }
    });

    test('contains every profile-scoped keepAlive provider', () {
      for (final provider in profileScopedKeepAliveEntries.values) {
        expect(profileScopedProviders, contains(provider));
      }
    });

    test('contains the unread notifications counter', () {
      expect(
          profileScopedProviders, contains(unreadNotificationsCountProvider));
    });

    test('has no duplicates', () {
      expect(
        profileScopedProviders.toSet().length,
        profileScopedProviders.length,
      );
    });
  });

  group('the guard itself fails when it should (mutation checks)', () {
    const registered = {'userClassesProvider'};
    const allowlisted = {'configProvider'};

    test('a new unregistered keepAlive provider is reported', () {
      final missing = unregisteredKeepAlive(
        {
          'lib/features/x/presentation/providers/x_providers.dart': '''
final myNewCachedProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
  return 1;
});
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, {'myNewCachedProvider'});
    });

    test('a registered or allowlisted provider passes', () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
final userClassesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.keepAlive();
  return 1;
});
final configProvider = FutureProvider<int>((ref) async {
  ref.keepAlive();
  return 1;
});
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, isEmpty);
    });

    test('a keepAlive inside a notifier class is attributed to the class', () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
final somethingProvider = AsyncNotifierProvider.autoDispose<NewNotifier, int>(
  NewNotifier.new,
);

class NewNotifier extends AutoDisposeAsyncNotifier<int> {
  @override
  Future<int> build() async {
    final link = ref.keepAlive();
    return 1;
  }
}
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, {'NewNotifier'});
    });

    test('a keepAlive in a top-level helper function is reported by its name',
        () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
final userClassesProvider = FutureProvider.autoDispose<int>((ref) async {
  return 1;
});

Future<int> loadSomething(Ref ref) async {
  ref.keepAlive();
  return 1;
}
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, {'loadSomething'});
    });

    test('mentions in comments are not calls', () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
/// autoDispose + keepAlive(): documented only
final plainProvider = Provider<int>((ref) {
  // ref.keepAlive();
  return 1;
});
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, isEmpty);
    });

    // --- Riverpod 3 declaration forms (change riverpod-3-migration, R2) -----

    test(
        'S2.2: an unregistered keepAlive in an AsyncNotifier class is reported',
        () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
final somethingProvider =
    AsyncNotifierProvider.autoDispose<NewFormNotifier, int>(
  NewFormNotifier.new,
);

class NewFormNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final link = ref.keepAlive();
    return 1;
  }
}
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(missing, {'NewFormNotifier'});
    });

    test('S2.2: same for Notifier, family classes and mixed old/new forms', () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
class SyncNotifierNew extends Notifier<int> {
  @override
  int build() {
    ref.keepAlive();
    return 1;
  }
}

class FamilyNotifierNew extends AsyncNotifier<int> {
  FamilyNotifierNew(this.arg);

  final int arg;

  @override
  Future<int> build() async {
    ref.keepAlive();
    return arg;
  }
}

class OldFormNotifier extends AutoDisposeAsyncNotifier<int> {
  @override
  Future<int> build() async {
    ref.keepAlive();
    return 1;
  }
}

class NoKeepAliveNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 1;
}
''',
        },
        registered: registered,
        allowlisted: allowlisted,
      );
      expect(
          missing, {'SyncNotifierNew', 'FamilyNotifierNew', 'OldFormNotifier'});
    });

    test('S2.2: registered or allowlisted new-form notifiers pass', () {
      final missing = unregisteredKeepAlive(
        {
          'a.dart': '''
class UserClassesNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    ref.keepAlive();
    return 1;
  }
}
''',
        },
        registered: const {'UserClassesNotifier'},
        allowlisted: allowlisted,
      );
      expect(missing, isEmpty);
    });
  });
}

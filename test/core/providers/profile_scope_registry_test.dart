import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/core/providers/profile_scope_registry.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

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
  });
}

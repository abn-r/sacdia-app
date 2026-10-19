import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/storage/image_cache_purge.dart';

/// S5 (re-verify 2b): las fotos y evidencias de un dependiente no pueden
/// sobrevivir en los cachés de imágenes.

class _FakeManager implements BaseCacheManager {
  _FakeManager({this.fails = false});

  final bool fails;
  int emptied = 0;

  @override
  Future<void> emptyCache() async {
    emptied++;
    if (fails) throw StateError('disk gone');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyCompleter extends ImageStreamCompleter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empties every manager even when one of them fails', () async {
    final failing = _FakeManager(fails: true);
    final ok = _FakeManager();

    await clearImageCaches(managers: [failing, ok]);

    expect(failing.emptied, 1);
    expect(ok.emptied, 1, reason: 'a failing store must not stop the rest');
  });

  test('also clears the decoded in-memory image cache', () async {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = 10;
    cache.putIfAbsent('dependent-photo', _EmptyCompleter.new);
    expect(cache.containsKey('dependent-photo'), isTrue);

    await clearImageCaches(managers: const []);

    expect(cache.containsKey('dependent-photo'), isFalse);
  });
}

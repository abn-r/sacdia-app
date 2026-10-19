import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/storage/local_storage.dart';
import 'package:sacdia_app/features/post_registration/data/health_none_disk_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// W1 (re-verify 2b): las marcas "ninguna alergia/enfermedad/medicina" del
/// paso 2 son un dato de salud y se purgan por usuario.

void main() {
  late SharedPreferences prefs;
  late LocalStorage storage;

  Set<String> flags() =>
      prefs.getKeys().where((k) => k.startsWith('post_registration.')).toSet();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'post_registration.health_none.guardian-1.allergies': true,
      'post_registration.health_none.guardian-1.diseases': true,
      'post_registration.health_none.guardian-10.allergies': true,
      'post_registration.health_none.ana-1.medicines': true,
      'post_registration.other_flag': true,
      'unrelated': 'keep',
    });
    prefs = await SharedPreferences.getInstance();
    storage = SharedPreferencesStorage(prefs);
  });

  test('keeps only the guardian flags and never confuses id prefixes',
      () async {
    await clearHealthNoneFlags(storage, keepUserId: 'guardian-1');

    expect(flags(), {
      'post_registration.health_none.guardian-1.allergies',
      'post_registration.health_none.guardian-1.diseases',
      'post_registration.other_flag',
    });
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('without a guardian id every health_none flag goes', () async {
    await clearHealthNoneFlags(storage);

    expect(flags(), {'post_registration.other_flag'});
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('the key helper matches what the step writes', () {
    expect(
      healthNoneKey('u1', 'allergies'),
      'post_registration.health_none.u1.allergies',
    );
  });
}

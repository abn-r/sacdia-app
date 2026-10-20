import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/session_mode.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeSecureStorage;

void main() {
  group('SessionMode.parse', () {
    test('only the exact device flag is a device; anything else is an account',
        () {
      expect(SessionMode.parse('device'), SessionMode.device);
      expect(SessionMode.parse(null), SessionMode.account);
      expect(SessionMode.parse(''), SessionMode.account);
      expect(SessionMode.parse('DEVICE'), SessionMode.account);
      expect(SessionMode.parse('teen'), SessionMode.account);
    });
  });

  group('SessionModeStore', () {
    test('writes device under session_mode and nothing for account', () async {
      final storage = FakeSecureStorage();
      final store = SessionModeStore(storage);

      expect(await store.read(), SessionMode.account);
      await store.write(SessionMode.device);
      expect(await storage.read(AppConstants.sessionModeKey), 'device');
      expect(await store.read(), SessionMode.device);

      await store.write(SessionMode.account);
      expect(await storage.contains(AppConstants.sessionModeKey), isFalse);
      expect(await store.read(), SessionMode.account);
    });

    test('clear removes the flag', () async {
      final storage = FakeSecureStorage();
      final store = SessionModeStore(storage);
      await store.write(SessionMode.device);

      await store.clear();

      expect(await storage.contains(AppConstants.sessionModeKey), isFalse);
    });

    test('a storage failure reads as an account, never as a device', () async {
      final store = SessionModeStore(_ThrowingStorage());
      expect(await store.read(), SessionMode.account);
      // Escribir tampoco lanza.
      await store.write(SessionMode.device);
    });
  });
}

class _ThrowingStorage extends FakeSecureStorage {
  @override
  Future<String?> read(String key) async => throw StateError('keychain');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('keychain');
}

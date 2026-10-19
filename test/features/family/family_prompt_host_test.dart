import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/family/presentation/widgets/family_prompt_host.dart';

UserEntity _user({
  String id = 'guardian-1',
  bool complete = false,
  ActingForInfo? actingFor,
}) =>
    UserEntity(
      id: id,
      name: 'María',
      postRegisterComplete: complete,
      actingFor: actingFor,
    );

void main() {
  group('shouldPromptFamily', () {
    test('asks right after the guardian finishes their own post-registration',
        () {
      expect(
        shouldPromptFamily(_user(), _user(complete: true), acting: false),
        isTrue,
      );
    });

    test('does not ask again on later launches (already complete)', () {
      expect(
        shouldPromptFamily(
          _user(complete: true),
          _user(complete: true),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask on the very first load of a complete user', () {
      expect(
        shouldPromptFamily(null, _user(complete: true), acting: false),
        isFalse,
      );
    });

    test('does not ask when a dependent finishes post-registration', () {
      expect(
        shouldPromptFamily(_user(), _user(complete: true), acting: true),
        isFalse,
      );
      expect(
        shouldPromptFamily(
          _user(id: 'ana-1'),
          _user(
            id: 'ana-1',
            complete: true,
            actingFor: const ActingForInfo(
              actorUserId: 'guardian-1',
              dependentUserId: 'ana-1',
            ),
          ),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask when the user changed', () {
      expect(
        shouldPromptFamily(
          _user(),
          _user(id: 'other', complete: true),
          acting: false,
        ),
        isFalse,
      );
    });

    test('does not ask on logout', () {
      expect(
        shouldPromptFamily(_user(complete: true), null, acting: false),
        isFalse,
      );
    });
  });
}

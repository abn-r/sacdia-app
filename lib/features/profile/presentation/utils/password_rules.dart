import '../../../../core/utils/validators.dart';

/// The visible rules of a NEW password. They mirror `Validators.validatePassword`
/// (and so the backend `NEW_PASSWORD_COMPLEXITY`): the same length, cases,
/// number and special characters. The validator stays the final check on submit
/// (it also covers the maximum length and the first character).
enum PasswordRule { length, letters, number, special }

/// Whether [password] satisfies [rule].
bool isPasswordRuleMet(PasswordRule rule, String password) {
  switch (rule) {
    case PasswordRule.length:
      return password.length >= Validators.newPasswordMinLength;
    case PasswordRule.letters:
      return RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'[a-z]').hasMatch(password);
    case PasswordRule.number:
      return RegExp(r'[0-9]').hasMatch(password);
    case PasswordRule.special:
      return RegExp('[${RegExp.escape(Validators.newPasswordSpecialChars)}]')
          .hasMatch(password);
  }
}

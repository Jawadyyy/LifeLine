class AuthValidators {
  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  static bool isValidPassword(String password, {int minLength = 6}) =>
      password.trim().length >= minLength;

  static bool isNonEmpty(String value) => value.trim().isNotEmpty;
}

class AuthResult<T> {
  final bool isSuccess;
  final T? data;
  final String? message;

  const AuthResult._(this.isSuccess, this.data, this.message);

  factory AuthResult.success([T? data, String? message]) =>
      AuthResult._(true, data, message);

  factory AuthResult.failure(String message) =>
      AuthResult._(false, null, message);
}

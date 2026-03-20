/// An exception whose message is safe to display directly to the user.
///
/// Throw this (instead of a generic [Exception]) whenever the message has
/// already been translated into a user-friendly string. Callers can then
/// distinguish it from unexpected internal errors and show the message
/// verbatim rather than a generic fallback.
class UserFacingException implements Exception {
  const UserFacingException(this.message);

  final String message;

  @override
  String toString() => message;
}

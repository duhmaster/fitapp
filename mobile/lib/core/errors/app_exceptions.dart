/// Thrown when API returns 4xx/5xx or network fails.
class AppException implements Exception {
  AppException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'AppException: $message${statusCode != null ? ' ($statusCode)' : ''}';
}

/// 401 Unauthorized — token missing or invalid.
class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized']) : super(message, statusCode: 401);
}

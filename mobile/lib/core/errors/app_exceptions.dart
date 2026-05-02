/// Thrown when API returns 4xx/5xx or network fails.
class AppException implements Exception {
  AppException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  bool get isPremiumRequired => code == 'premium_required';
  bool get isCoachProRequired => code == 'coach_pro_required';

  @override
  String toString() {
    final withStatus = statusCode != null ? ' ($statusCode)' : '';
    final withCode = code != null && code!.isNotEmpty ? ' [$code]' : '';
    return 'AppException: $message$withStatus$withCode';
  }
}

/// 401 Unauthorized — token missing or invalid.
class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized'])
      : super(message, statusCode: 401);
}

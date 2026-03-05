class LoginRequest {
  LoginRequest({required this.email, required this.password});
  final String email;
  final String password;
  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
  });
  final String email;
  final String password;
  final String name;
  Map<String, dynamic> toJson() =>
      {'email': email, 'password': password, 'name': name};
}

class AuthResponse {
  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
    );
  }
}

/// Current user from GET /api/v1/me (includes theme, locale, subscription).
class CurrentUser {
  CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    this.theme,
    this.locale,
    this.paidSubscriber = false,
    this.subscriptionExpiresAt,
  });
  final String id;
  final String email;
  final String role;
  final String? theme;
  final String? locale;
  final bool paidSubscriber;
  final String? subscriptionExpiresAt;
  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      theme: json['theme'] as String?,
      locale: json['locale'] as String?,
      paidSubscriber: json['paid_subscriber'] as bool? ?? false,
      subscriptionExpiresAt: json['subscription_expires_at'] as String?,
    );
  }
}

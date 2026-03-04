/// Form field validators used across the app.
class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? minLength(String? value, int min, [String fieldName = 'Field']) {
    if (value == null) return '$fieldName is required';
    if (value.length < min) return '$fieldName must be at least $min characters';
    return null;
  }

  static String? numberInRange(
    String? value, {
    double? min,
    double? max,
    String fieldName = 'Value',
    bool allowEmpty = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return allowEmpty ? null : '$fieldName is required';
    }
    final n = double.tryParse(value.trim().replaceAll(',', '.'));
    if (n == null) return 'Enter a valid number';
    if (min != null && n < min) return '$fieldName must be at least $min';
    if (max != null && n > max) return '$fieldName must be at most $max';
    return null;
  }

  static String? heightCm(String? value) =>
      numberInRange(value, min: 50, max: 250, fieldName: 'Height');

  static String? weightKg(String? value) =>
      numberInRange(value, min: 20, max: 300, fieldName: 'Weight');

  static String? bodyFatPct(String? value) =>
      numberInRange(value, min: 0, max: 100, fieldName: 'Body fat %');
}

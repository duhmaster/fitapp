/// Optional wrapper for API responses that return { "data": T } or { "error": "..." }.
/// Our API mostly returns raw entities; use this when you add standardized envelope later.
class BaseResponse<T> {
  BaseResponse({this.data, this.error});
  final T? data;
  final String? error;

  bool get isSuccess => error == null && data != null;
}

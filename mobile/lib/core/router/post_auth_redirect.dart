/// Validates [redirect] query from login/register: only in-app path `/g/:trainingId`.
bool isAllowedPostAuthRedirect(String? redirect) {
  if (redirect == null || redirect.isEmpty) return false;
  if (!redirect.startsWith('/') || redirect.startsWith('//') || redirect.contains('..')) {
    return false;
  }
  final segments = Uri.parse(redirect).pathSegments;
  return segments.length == 2 && segments[0] == 'g' && segments[1].isNotEmpty;
}

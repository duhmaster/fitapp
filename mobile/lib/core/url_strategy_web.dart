/// On web, we do NOT set path URL strategy so Flutter keeps the default hash
/// strategy (#/home, #/profile). That prevents full page reloads when tapping
/// nav buttons, since the server never receives requests for /profile etc.
void usePathUrlStrategy() {
  // No-op: keep default HashUrlStrategy so in-app navigation does not reload.
}

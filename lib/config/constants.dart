/// ULink CLI embedded configuration constants
/// These values are embedded in the CLI binary for security and performance
class ULinkConstants {
  /// Supabase project URL for authentication
  static const String supabaseUrl = 'https://cjgihassfsspxivjtgoi.supabase.co';

  /// Supabase publishable key (`sb_publishable_...`) for authentication.
  /// This is a public key designed to be embedded in client applications.
  /// It replaced the legacy JWT anon key, which Supabase is retiring.
  static const String supabaseAnonKey =
      'sb_publishable_DeLGAeipTSnGxvAH3AdlZQ_eXNVNIvs';

  /// The key to send to Supabase Auth for a stored config.
  ///
  /// CLI versions up to 1.4.3 embedded the legacy JWT anon key and saved it
  /// into `~/.ulink/config.json` at login, and token refresh reads it from
  /// there. Once Supabase disables legacy keys those refreshes fail, so for
  /// the production project a stored legacy (JWT-format) key is replaced by
  /// the embedded publishable key. Configs for any other Supabase project
  /// (e.g. a local stack set via SUPABASE_URL at login) are left untouched.
  static String resolveSupabaseKey({
    required String? supabaseUrl,
    required String storedKey,
  }) {
    final isProduction =
        supabaseUrl != null && _normalizeUrl(supabaseUrl) == _productionUrl;
    return isProduction && _isLegacyJwtKey(storedKey)
        ? supabaseAnonKey
        : storedKey;
  }

  static final String _productionUrl = _normalizeUrl(supabaseUrl);

  static String _normalizeUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  static bool _isLegacyJwtKey(String key) =>
      key.startsWith('eyJ') && key.split('.').length == 3;
}

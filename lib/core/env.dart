class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  // Set this to your Cloudflare Pages URL in production.
  // In dev, 'http://localhost' is fine — Supabase handles the hash token directly.
  static const redirectUrl = String.fromEnvironment(
    'REDIRECT_URL',
    defaultValue: 'http://localhost',
  );
}

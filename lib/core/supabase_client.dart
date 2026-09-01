import 'package:tally/core/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
}

// Top-level getter — import this wherever you need to hit the DB or Auth.
SupabaseClient get supabase => Supabase.instance.client;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialises a throwaway Supabase instance so screens that read
/// `supabase.auth.currentUser` at build time can be pumped in widget tests.
/// No network calls are made; `currentUser` is null (logged out).
Future<void> initTestSupabase() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Stub the plugins Supabase touches during initialize() so nothing throws
  // a MissingPluginException on the test platform.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => call.method == 'getAll' ? <String, Object>{} : null,
  );
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/messages'),
    (call) async => null,
  );

  await Supabase.initialize(
    url: 'http://localhost:54321',
    anonKey: 'test-anon-key',
    debug: false,
  );
}

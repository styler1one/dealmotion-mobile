import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

/// Dev mode flag - allows skipping real authentication
bool _devModeAuthenticated = false;

/// Set dev mode authentication (for testing without real login)
void setDevModeAuthenticated(bool value) {
  _devModeAuthenticated = value;
}

/// Initialize Supabase client
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );
}

/// Get Supabase client instance
SupabaseClient get supabase => Supabase.instance.client;

/// Get current user
User? get currentUser => supabase.auth.currentUser;

/// Get current session
Session? get currentSession => supabase.auth.currentSession;

/// Check if user is authenticated (includes dev mode)
bool get isAuthenticated => currentUser != null || _devModeAuthenticated;


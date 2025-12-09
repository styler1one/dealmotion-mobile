import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart' show supabase, currentSession, setDevModeAuthenticated;

/// Auth state enum
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// Auth notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _initialize();
  }

  void _initialize() {
    // Check current session on startup
    final session = currentSession;
    if (session != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Listen to auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          state = AuthState(
            status: AuthStatus.authenticated,
            user: session?.user,
          );
          break;
        case AuthChangeEvent.signedOut:
          state = const AuthState(status: AuthStatus.unauthenticated);
          break;
        case AuthChangeEvent.tokenRefreshed:
          if (session != null) {
            state = AuthState(
              status: AuthStatus.authenticated,
              user: session.user,
            );
          }
          break;
        case AuthChangeEvent.userUpdated:
          state = state.copyWith(user: session?.user);
          break;
        default:
          break;
      }
    });
  }

  /// Sign in with Google OAuth
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'dealmotion://auth/callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Auth state change listener will handle the rest
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await supabase.auth.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(
      status: state.user != null 
        ? AuthStatus.authenticated 
        : AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }

  /// Skip login for dev mode (simulates authenticated state without real auth)
  void skipLoginForDev() {
    setDevModeAuthenticated(true);
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: null, // No real user, but marked as authenticated
    );
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Convenience provider for getting current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});


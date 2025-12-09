import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_config.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/meetings/presentation/meetings_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/prospects/presentation/prospects_screen.dart';
import '../../features/prospects/presentation/prospect_hub_screen.dart';
import '../../features/recording/presentation/recording_screen.dart';
import '../../features/recordings/presentation/recordings_history_screen.dart';
import '../../features/research/presentation/research_create_screen.dart';
import '../../features/research/presentation/research_detail_screen.dart';
import '../../features/preparation/presentation/preparation_create_screen.dart';
import '../../features/preparation/presentation/preparation_detail_screen.dart';
import '../../features/followup/presentation/followup_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/widgets/main_shell.dart';

/// App route paths
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String authCallback = '/auth/callback';
  
  // Shell routes (bottom nav)
  static const String home = '/home';
  static const String meetings = '/meetings';
  static const String prospects = '/prospects';
  static const String more = '/more';
  
  // Detail routes (push on top of shell)
  static const String recording = '/recording';
  static const String recordings = '/recordings';
  static const String settings = '/settings';
  
  // Research routes
  static const String researchCreate = '/research/create';
  static const String researchDetail = '/research/:id';
  
  // Preparation routes
  static const String preparationCreate = '/preparation/create';
  static const String preparationDetail = '/preparation/:id';
  
  // Followup routes
  static const String followupDetail = '/followup/:id';
  
  // Prospect routes
  static const String prospectHub = '/prospect/:id';
}

// Navigation key for root navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration with StatefulShellRoute for bottom navigation
final goRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  navigatorKey: _rootNavigatorKey,
  debugLogDiagnostics: true,
  
  // Redirect based on auth state
  redirect: (context, state) {
    final isLoggedIn = isAuthenticated;
    final isLoggingIn = state.matchedLocation == AppRoutes.login;
    final isAuthCallback = state.matchedLocation == AppRoutes.authCallback;
    final isSplash = state.matchedLocation == AppRoutes.splash;

    // Allow splash screen to proceed
    if (isSplash) return null;

    // Allow auth callback to proceed
    if (isAuthCallback) return null;

    // If not logged in and not on login page, redirect to login
    if (!isLoggedIn && !isLoggingIn) {
      return AppRoutes.login;
    }

    // If logged in and on login page, redirect to home
    if (isLoggedIn && isLoggingIn) {
      return AppRoutes.home;
    }

    return null;
  },
  
  routes: [
    // Splash screen
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    
    // Login screen
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    // Auth callback
    GoRoute(
      path: AppRoutes.authCallback,
      name: 'authCallback',
      builder: (context, state) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    ),
    
    // Main app shell with bottom navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        
        // Branch 1: Meetings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.meetings,
              name: 'meetings',
              builder: (context, state) => const MeetingsScreen(),
            ),
          ],
        ),
        
        // Branch 2: Prospects
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.prospects,
              name: 'prospects',
              builder: (context, state) => const ProspectsScreen(),
            ),
          ],
        ),
        
        // Branch 3: More
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.more,
              name: 'more',
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
    
    // Detail routes (outside shell, push on top)
    GoRoute(
      path: AppRoutes.recording,
      name: 'recording',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final prospectId = state.uri.queryParameters['prospectId'];
        final prospectName = state.uri.queryParameters['prospectName'];
        return RecordingScreen(
          prospectId: prospectId,
          prospectName: prospectName,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.recordings,
      name: 'recordings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecordingsHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    
    // Research routes
    GoRoute(
      path: AppRoutes.researchCreate,
      name: 'researchCreate',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ResearchCreateScreen(),
    ),
    GoRoute(
      path: '/research/:id',
      name: 'researchDetail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ResearchDetailScreen(researchId: id);
      },
    ),
    
    // Preparation routes
    GoRoute(
      path: AppRoutes.preparationCreate,
      name: 'preparationCreate',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PreparationCreateScreen(),
    ),
    GoRoute(
      path: '/preparation/:id',
      name: 'preparationDetail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PreparationDetailScreen(preparationId: id);
      },
    ),
    
    // Followup routes
    GoRoute(
      path: '/followup/:id',
      name: 'followupDetail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return FollowupDetailScreen(followupId: id);
      },
    ),
    
    // Prospect hub route
    GoRoute(
      path: '/prospect/:id',
      name: 'prospectHub',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProspectHubScreen(prospectId: id);
      },
    ),
  ],
  
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Page not found: ${state.uri.path}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  ),
);

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

/// Service for handling deep links
class DeepLinkService {
  static DeepLinkService? _instance;
  
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  BuildContext? _context;

  DeepLinkService._();

  static DeepLinkService get instance {
    _instance ??= DeepLinkService._();
    return _instance!;
  }

  /// Initialize deep link handling
  Future<void> initialize(BuildContext context) async {
    _context = context;

    // Handle initial deep link (app opened via link)
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Listen for incoming deep links
    _subscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) {
        debugPrint('Deep link error: $e');
      },
    );
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    if (_context == null) return;

    debugPrint('Handling deep link: $uri');

    // Parse the URI and navigate
    final path = uri.path;
    final queryParams = uri.queryParameters;

    // Handle different deep link patterns
    if (uri.scheme == 'dealmotion') {
      _handleAppSchemeLink(path, queryParams);
    } else if (uri.host == 'dealmotion.ai') {
      _handleUniversalLink(path, queryParams);
    }
  }

  void _handleAppSchemeLink(String path, Map<String, String> params) {
    switch (path) {
      case '/auth/callback':
        // OAuth callback - handled by Supabase
        break;
        
      case '/recording':
        final prospectId = params['prospectId'];
        final prospectName = params['prospectName'];
        if (prospectId != null) {
          _navigate('${AppRoutes.recording}?prospectId=$prospectId&prospectName=${Uri.encodeComponent(prospectName ?? '')}');
        } else {
          _navigate(AppRoutes.recording);
        }
        break;
        
      case '/prospect':
        final prospectId = params['id'];
        if (prospectId != null) {
          // Navigate to prospect details (if we have that screen)
          _navigate(AppRoutes.prospects);
        }
        break;
        
      case '/followup':
        final followupId = params['id'];
        if (followupId != null) {
          // Would navigate to followup details
          // For now, go to prospects
          _navigate(AppRoutes.prospects);
        }
        break;
        
      default:
        _navigate(AppRoutes.prospects);
    }
  }

  void _handleUniversalLink(String path, Map<String, String> params) {
    // Handle https://dealmotion.ai/mobile/... links
    if (path.startsWith('/mobile')) {
      final mobilePath = path.replaceFirst('/mobile', '');
      _handleAppSchemeLink(mobilePath, params);
    }
  }

  void _navigate(String path) {
    if (_context != null) {
      GoRouter.of(_context!).go(path);
    }
  }

  /// Create a deep link for recording with a prospect
  static String createRecordingLink({
    String? prospectId,
    String? prospectName,
  }) {
    final params = <String, String>{};
    if (prospectId != null) params['prospectId'] = prospectId;
    if (prospectName != null) params['prospectName'] = prospectName;
    
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return 'dealmotion://recording${query.isNotEmpty ? '?$query' : ''}';
  }

  /// Create a universal link
  static String createUniversalLink(String path, [Map<String, String>? params]) {
    final query = params?.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&') ?? '';
    
    return 'https://dealmotion.ai/mobile$path${query.isNotEmpty ? '?$query' : ''}';
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _context = null;
  }
}


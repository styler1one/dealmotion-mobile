import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';

/// Notification service for handling push notifications
class NotificationService {
  static NotificationService? _instance;
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _initialized = false;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Check if notifications are enabled
  Future<bool> get areNotificationsEnabled async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Request permission
    await requestPermission();

    // Initialize local notifications
    await _initLocalNotifications();

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerTokenWithBackend(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Register token with backend
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    }

    _initialized = true;
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'dealmotion_notifications',
              'DealMotion Notifications',
              description: 'Notifications from DealMotion',
              importance: Importance.high,
            ),
          );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    _showLocalNotification(
      title: message.notification?.title ?? 'DealMotion',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    // Handle notification tap - navigate to appropriate screen
    final data = message.data;
    
    if (data.containsKey('recording_id')) {
      // Navigate to recording details
      // TODO: Use go_router to navigate
    } else if (data.containsKey('followup_id')) {
      // Navigate to followup details
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle local notification tap
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dealmotion_notifications',
      'DealMotion Notifications',
      channelDescription: 'Notifications from DealMotion',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiService.instance.post(
        '/api/v1/mobile/register-device',
        data: {
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
    } catch (e) {
      // Ignore errors - will retry on next app launch
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Show upload complete notification
  Future<void> showUploadCompleteNotification({
    required String prospectName,
    required String recordingId,
  }) async {
    await _showLocalNotification(
      title: 'Recording Uploaded',
      body: 'Your recording with $prospectName is ready for analysis.',
      payload: 'recording:$recordingId',
    );
  }

  /// Show analysis complete notification
  Future<void> showAnalysisCompleteNotification({
    required String prospectName,
    required String followupId,
  }) async {
    await _showLocalNotification(
      title: 'Analysis Complete',
      body: 'Your meeting with $prospectName has been analyzed.',
      payload: 'followup:$followupId',
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});


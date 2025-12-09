import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground service for background recording
/// Note: This only works on Android/iOS, not web
class RecordingForegroundService {
  static RecordingForegroundService? _instance;
  
  RecordingForegroundService._();
  
  static RecordingForegroundService get instance {
    _instance ??= RecordingForegroundService._();
    return _instance!;
  }

  /// Initialize the foreground task
  Future<void> initialize() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'dealmotion_recording',
          channelName: 'Recording Service',
          channelDescription: 'DealMotion is recording your meeting',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
          playSound: false,
          enableVibration: false,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e) {
      // Ignore errors on unsupported platforms (web)
    }
  }

  /// Start the foreground service for recording
  Future<bool> startService({
    String? prospectName,
  }) async {
    try {
      // Check if already running
      if (await FlutterForegroundTask.isRunningService) {
        return true;
      }

      // Request permissions
      final notificationPermission = 
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Start the service
      await FlutterForegroundTask.startService(
        notificationTitle: 'Recording in progress',
        notificationText: prospectName != null 
            ? 'Meeting with $prospectName'
            : 'Tap to return to DealMotion',
        callback: startCallback,
      );
      
      return true;
    } catch (e) {
      // Foreground service not available (web)
      return false;
    }
  }

  /// Update notification text (e.g., with duration)
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      // Ignore on unsupported platforms
    }
  }

  /// Stop the foreground service
  Future<bool> stopService() async {
    try {
      await FlutterForegroundTask.stopService();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if service is running
  Future<bool> get isRunning async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (e) {
      return false;
    }
  }
}

/// Callback function for foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// Task handler for the foreground service
class RecordingTaskHandler extends TaskHandler {
  int _seconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _seconds = 0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _seconds += 5;
    
    // Update notification with duration
    final duration = Duration(seconds: _seconds);
    final formatted = _formatDuration(duration);
    
    FlutterForegroundTask.updateService(
      notificationTitle: 'Recording: $formatted',
      notificationText: 'Tap to return to DealMotion',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button presses
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // User tapped the notification - bring app to foreground
    FlutterForegroundTask.launchApp('/recording');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

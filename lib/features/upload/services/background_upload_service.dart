import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/supabase_config.dart' as supabase_config;
import '../../../shared/models/local_recording.dart';

/// Global upload progress notifier for UI updates
class UploadProgressTracker {
  static final UploadProgressTracker instance = UploadProgressTracker._();
  UploadProgressTracker._();

  final ValueNotifier<Map<String, double>> progressMap = ValueNotifier({});
  final ValueNotifier<String?> currentUploadId = ValueNotifier(null);
  final ValueNotifier<bool> isUploading = ValueNotifier(false);
  
  /// Notifies when any upload status changes (for UI refresh)
  final ValueNotifier<int> uploadChangeCounter = ValueNotifier(0);

  void startUpload(String id) {
    currentUploadId.value = id;
    isUploading.value = true;
    progressMap.value = {...progressMap.value, id: 0.0};
  }

  void updateProgress(String id, double progress) {
    progressMap.value = {...progressMap.value, id: progress};
  }

  void completeUpload(String id) {
    progressMap.value = {...progressMap.value, id: 1.0};
    if (currentUploadId.value == id) {
      currentUploadId.value = null;
    }
    // Notify UI to refresh
    uploadChangeCounter.value++;
    // Remove from map after delay
    Future.delayed(const Duration(seconds: 2), () {
      final map = Map<String, double>.from(progressMap.value);
      map.remove(id);
      progressMap.value = map;
    });
  }

  void failUpload(String id) {
    final map = Map<String, double>.from(progressMap.value);
    map.remove(id);
    progressMap.value = map;
    if (currentUploadId.value == id) {
      currentUploadId.value = null;
    }
    // Notify UI to refresh
    uploadChangeCounter.value++;
  }

  void reset() {
    progressMap.value = {};
    currentUploadId.value = null;
    isUploading.value = false;
  }
}

/// Task names for background uploads
class BackgroundTasks {
  static const String uploadPending = 'uploadPendingRecordings';
  static const String retryFailed = 'retryFailedUploads';
  static const String cleanup = 'cleanupOldRecordings';
}

/// Initialize background upload service
/// Note: workmanager is temporarily disabled due to compatibility issues
/// Background uploads are handled manually when app is in foreground
Future<void> initializeBackgroundUpload() async {
  // Workmanager disabled for now - using manual upload approach
  // Background upload will be triggered when:
  // 1. App comes to foreground
  // 2. Recording is saved
  // 3. Network connectivity is restored
  debugPrint('Background upload service initialized (manual mode)');
}

/// Cancel all background tasks
Future<void> cancelBackgroundUpload() async {
  // No-op for now
}

/// Trigger immediate upload of pending recordings
/// This can be called from the app when network is available
Future<void> triggerImmediateUpload() async {
  await uploadPendingRecordings();
}

/// Upload all pending recordings
/// This is called manually instead of via workmanager
Future<bool> uploadPendingRecordings() async {
  try {
    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return true; // Will retry later
    }

    // Open Hive box
    final box = await Hive.openBox<LocalRecording>('local_recordings');
    
    // Get pending recordings
    final pending = box.values
        .where((r) => r.uploadStatus == RecordingUploadStatus.pending)
        .toList();

    if (pending.isEmpty) {
      await box.close();
      return true;
    }

    // Get auth token
    final accessToken = supabase_config.currentSession?.accessToken;
    if (accessToken == null) {
      debugPrint('Upload skipped: No auth token');
      return false; // Not authenticated
    }

    // Create Dio instance for uploads with auth
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    ));

    int successCount = 0;
    int failCount = 0;

    debugPrint('Uploading ${pending.length} pending recordings...');

    final tracker = UploadProgressTracker.instance;
    tracker.isUploading.value = true;

    for (final recording in pending) {
      try {
        debugPrint('Processing recording: ${recording.id}');
        
        // Check if file exists
        final file = File(recording.filePath);
        if (!await file.exists()) {
          debugPrint('File not found: ${recording.filePath}');
          recording.uploadStatus = RecordingUploadStatus.failed;
          recording.uploadError = 'File not found';
          await recording.save();
          failCount++;
          continue;
        }

        // Mark as uploading
        recording.uploadStatus = RecordingUploadStatus.uploading;
        await recording.save();
        
        // Start tracking progress
        tracker.startUpload(recording.id);

        // Prepare form data
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            recording.filePath,
            filename: 'recording.m4a',
          ),
          'prospect_id': recording.prospectId ?? '',
          'prospect_name': recording.prospectName ?? '',
          'duration_seconds': recording.durationSeconds,
          'local_recording_id': recording.id,
        });

        debugPrint('Uploading to ${AppConfig.apiBaseUrl}/api/v1/mobile/recordings/upload');

        // Upload with progress tracking
        final response = await dio.post(
          '/api/v1/mobile/recordings/upload',
          data: formData,
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              tracker.updateProgress(recording.id, progress);
              debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
            }
          },
        );

        debugPrint('Upload response: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final remoteId = response.data['recording_id'] as String?;
          recording.uploadStatus = RecordingUploadStatus.uploaded;
          recording.remoteId = remoteId;
          recording.uploadError = null;
          await recording.save();
          successCount++;
          tracker.completeUpload(recording.id);
          debugPrint('Upload success: ${recording.id}');
        } else {
          throw Exception('Upload failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Upload error for ${recording.id}: $e');
        recording.uploadStatus = RecordingUploadStatus.failed;
        recording.uploadError = e.toString();
        recording.uploadAttempts++;
        recording.lastUploadAttempt = DateTime.now();
        await recording.save();
        failCount++;
        tracker.failUpload(recording.id);
      }

      // Small delay between uploads
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    tracker.isUploading.value = false;

    await box.close();
    
    debugPrint('Upload completed: $successCount success, $failCount failed');
    return true;
  } catch (e) {
    debugPrint('Upload error: $e');
    return false;
  }
}

/// Retry failed uploads
Future<bool> retryFailedUploads() async {
  try {
    final box = await Hive.openBox<LocalRecording>('local_recordings');
    
    final failed = box.values
        .where((r) => 
            r.uploadStatus == RecordingUploadStatus.failed &&
            r.uploadAttempts < AppConfig.maxRetries)
        .toList();

    // Reset status to pending for retry
    for (final recording in failed) {
      recording.uploadStatus = RecordingUploadStatus.pending;
      await recording.save();
    }

    await box.close();

    // Trigger upload
    return await uploadPendingRecordings();
  } catch (e) {
    debugPrint('Retry error: $e');
    return false;
  }
}

/// Cleanup old uploaded recordings
Future<bool> cleanupOldRecordings() async {
  try {
    final box = await Hive.openBox<LocalRecording>('local_recordings');
    
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    
    final toDelete = box.values
        .where((r) => 
            r.uploadStatus == RecordingUploadStatus.uploaded &&
            r.createdAt.isBefore(cutoff))
        .toList();

    for (final recording in toDelete) {
      // Delete file
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      // Delete from Hive
      await recording.delete();
    }

    await box.close();
    
    debugPrint('Cleanup completed: ${toDelete.length} old recordings deleted');
    return true;
  } catch (e) {
    debugPrint('Cleanup error: $e');
    return false;
  }
}

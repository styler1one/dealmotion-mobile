import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/api_endpoints.dart';
import '../../../shared/models/local_recording.dart';
import '../../recording/data/local_recording_repository.dart';

/// Result of an upload attempt
class UploadResult {
  final bool success;
  final String? remoteId;
  final String? error;
  final double? progress;

  UploadResult({
    required this.success,
    this.remoteId,
    this.error,
    this.progress,
  });

  factory UploadResult.success(String remoteId) {
    return UploadResult(success: true, remoteId: remoteId);
  }

  factory UploadResult.failure(String error) {
    return UploadResult(success: false, error: error);
  }
}

/// Service for uploading recordings to the backend
class UploadService {
  static UploadService? _instance;
  
  final ApiService _apiService = ApiService.instance;
  final LocalRecordingRepository _localRepo = LocalRecordingRepository.instance;
  final Connectivity _connectivity = Connectivity();
  
  bool _isUploading = false;
  String? _currentUploadId;

  UploadService._();

  static UploadService get instance {
    _instance ??= UploadService._();
    return _instance!;
  }

  /// Check if currently uploading
  bool get isUploading => _isUploading;

  /// Get current upload ID
  String? get currentUploadId => _currentUploadId;

  /// Check if device has network connectivity
  Future<bool> hasConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Upload a single recording
  Future<UploadResult> uploadRecording(
    LocalRecording recording, {
    void Function(double progress)? onProgress,
  }) async {
    // Check connectivity
    if (!await hasConnectivity()) {
      return UploadResult.failure('No network connection');
    }

    // Check file exists
    final file = File(recording.filePath);
    if (!await file.exists()) {
      await _localRepo.markAsFailed(recording.id, 'Recording file not found');
      return UploadResult.failure('Recording file not found');
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize > AppConfig.maxFileSizeMB * 1024 * 1024) {
      await _localRepo.markAsFailed(recording.id, 'File too large');
      return UploadResult.failure('File exceeds maximum size of ${AppConfig.maxFileSizeMB}MB');
    }

    _isUploading = true;
    _currentUploadId = recording.id;

    try {
      // Mark as uploading
      await _localRepo.markAsUploading(recording.id);

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

      // Upload with progress
      final response = await _apiService.dio.post(
        ApiEndpoints.mobileRecordingsUpload,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            onProgress?.call(progress);
          }
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final remoteId = response.data['recording_id'] as String?;
        
        if (remoteId != null) {
          await _localRepo.markAsUploaded(recording.id, remoteId);
          return UploadResult.success(remoteId);
        }
      }

      final errorMsg = response.data?['detail'] ?? 'Upload failed';
      await _localRepo.markAsFailed(recording.id, errorMsg);
      return UploadResult.failure(errorMsg);

    } on DioException catch (e) {
      String errorMsg;
      
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection timeout';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMsg = 'Upload timeout';
      } else if (e.response?.statusCode == 413) {
        errorMsg = 'File too large';
      } else if (e.response?.statusCode == 401) {
        errorMsg = 'Authentication failed';
      } else {
        errorMsg = e.response?.data?['detail'] ?? e.message ?? 'Upload failed';
      }

      await _localRepo.markAsFailed(recording.id, errorMsg);
      return UploadResult.failure(errorMsg);

    } catch (e) {
      final errorMsg = e.toString();
      await _localRepo.markAsFailed(recording.id, errorMsg);
      return UploadResult.failure(errorMsg);

    } finally {
      _isUploading = false;
      _currentUploadId = null;
    }
  }

  /// Upload all pending recordings
  Future<Map<String, UploadResult>> uploadAllPending({
    void Function(String recordingId, double progress)? onProgress,
    void Function(String recordingId, UploadResult result)? onComplete,
  }) async {
    final results = <String, UploadResult>{};

    // Check connectivity
    if (!await hasConnectivity()) {
      return results;
    }

    // Get pending recordings
    await _localRepo.open();
    final pending = await _localRepo.getPendingRecordings();

    for (final recording in pending) {
      // Check if we still have connectivity
      if (!await hasConnectivity()) {
        break;
      }

      final result = await uploadRecording(
        recording,
        onProgress: (progress) {
          onProgress?.call(recording.id, progress);
        },
      );

      results[recording.id] = result;
      onComplete?.call(recording.id, result);

      // Small delay between uploads
      if (pending.indexOf(recording) < pending.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  /// Retry failed uploads
  Future<Map<String, UploadResult>> retryFailed({
    void Function(String recordingId, double progress)? onProgress,
    void Function(String recordingId, UploadResult result)? onComplete,
  }) async {
    final results = <String, UploadResult>{};

    await _localRepo.open();
    final all = await _localRepo.getAllRecordings();
    final failed = all.where((r) => 
        r.uploadStatus == RecordingUploadStatus.failed &&
        r.uploadAttempts < AppConfig.maxRetries
    ).toList();

    for (final recording in failed) {
      if (!await hasConnectivity()) break;

      final result = await uploadRecording(
        recording,
        onProgress: (progress) {
          onProgress?.call(recording.id, progress);
        },
      );

      results[recording.id] = result;
      onComplete?.call(recording.id, result);
    }

    return results;
  }

  /// Cancel current upload (if possible)
  void cancelCurrentUpload() {
    // Note: Dio doesn't support cancellation mid-upload easily
    // This is more of a flag for the UI
    _isUploading = false;
    _currentUploadId = null;
  }
}


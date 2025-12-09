import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/local_recording.dart';

/// Repository for managing local recordings in Hive
class LocalRecordingRepository {
  static const String _boxName = 'local_recordings';
  static LocalRecordingRepository? _instance;
  
  Box<LocalRecording>? _box;

  LocalRecordingRepository._();

  static LocalRecordingRepository get instance {
    _instance ??= LocalRecordingRepository._();
    return _instance!;
  }

  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocalRecordingAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RecordingUploadStatusAdapter());
    }
  }

  /// Open the recordings box
  Future<void> open() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<LocalRecording>(_boxName);
    }
  }

  /// Get the box, opening if necessary
  Future<Box<LocalRecording>> get box async {
    await open();
    return _box!;
  }

  /// Save a new recording
  Future<LocalRecording> saveRecording({
    required String filePath,
    required int durationSeconds,
    String? prospectId,
    String? prospectName,
  }) async {
    final recordingBox = await box;
    
    // Get file size
    final file = File(filePath);
    final fileSizeBytes = await file.length();

    final recording = LocalRecording(
      id: const Uuid().v4(),
      filePath: filePath,
      prospectId: prospectId,
      prospectName: prospectName,
      createdAt: DateTime.now(),
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
    );

    await recordingBox.put(recording.id, recording);
    return recording;
  }

  /// Get all recordings
  Future<List<LocalRecording>> getAllRecordings() async {
    final recordingBox = await box;
    return recordingBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get pending recordings (not yet uploaded)
  Future<List<LocalRecording>> getPendingRecordings() async {
    final recordings = await getAllRecordings();
    return recordings.where((r) => r.canUpload).toList();
  }

  /// Get a recording by ID
  Future<LocalRecording?> getRecording(String id) async {
    final recordingBox = await box;
    return recordingBox.get(id);
  }

  /// Update recording status
  Future<void> updateStatus(
    String id,
    RecordingUploadStatus status, {
    String? error,
    String? remoteId,
  }) async {
    final recordingBox = await box;
    final recording = recordingBox.get(id);
    
    if (recording != null) {
      recording.uploadStatus = status;
      recording.uploadError = error;
      recording.lastUploadAttempt = DateTime.now();
      recording.uploadAttempts += 1;
      if (remoteId != null) {
        recording.remoteId = remoteId;
      }
      await recording.save();
    }
  }

  /// Mark recording as uploading
  Future<void> markAsUploading(String id) async {
    await updateStatus(id, RecordingUploadStatus.uploading);
  }

  /// Mark recording as uploaded
  Future<void> markAsUploaded(String id, String remoteId) async {
    await updateStatus(
      id,
      RecordingUploadStatus.uploaded,
      remoteId: remoteId,
    );
  }

  /// Mark recording as failed
  Future<void> markAsFailed(String id, String error) async {
    await updateStatus(
      id,
      RecordingUploadStatus.failed,
      error: error,
    );
  }

  /// Delete a recording (both from Hive and file system)
  Future<void> deleteRecording(String id) async {
    final recordingBox = await box;
    final recording = recordingBox.get(id);
    
    if (recording != null) {
      // Delete the file
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Delete from Hive
      await recordingBox.delete(id);
    }
  }

  /// Delete all uploaded recordings (cleanup)
  Future<int> deleteUploadedRecordings() async {
    final recordings = await getAllRecordings();
    final uploaded = recordings.where((r) => r.isUploaded).toList();
    
    for (final recording in uploaded) {
      await deleteRecording(recording.id);
    }
    
    return uploaded.length;
  }

  /// Get total size of pending recordings
  Future<int> getPendingSize() async {
    final pending = await getPendingRecordings();
    return pending.fold<int>(0, (sum, r) => sum + r.fileSizeBytes);
  }

  /// Get count of recordings by status
  Future<Map<RecordingUploadStatus, int>> getStatusCounts() async {
    final recordings = await getAllRecordings();
    final counts = <RecordingUploadStatus, int>{};
    
    for (final status in RecordingUploadStatus.values) {
      counts[status] = recordings.where((r) => r.uploadStatus == status).length;
    }
    
    return counts;
  }

  /// Close the box
  Future<void> close() async {
    await _box?.close();
    _box = null;
  }
}


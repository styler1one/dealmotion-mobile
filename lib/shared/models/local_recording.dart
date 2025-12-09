import 'package:hive/hive.dart';

part 'local_recording.g.dart';

/// Status of a local recording
@HiveType(typeId: 1)
enum RecordingUploadStatus {
  @HiveField(0)
  pending,
  
  @HiveField(1)
  uploading,
  
  @HiveField(2)
  uploaded,
  
  @HiveField(3)
  failed,
}

/// Local recording model stored in Hive
@HiveType(typeId: 0)
class LocalRecording extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  final String? prospectId;

  @HiveField(3)
  final String? prospectName;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int durationSeconds;

  @HiveField(6)
  final int fileSizeBytes;

  @HiveField(7)
  RecordingUploadStatus uploadStatus;

  @HiveField(8)
  String? uploadError;

  @HiveField(9)
  int uploadAttempts;

  @HiveField(10)
  DateTime? lastUploadAttempt;

  @HiveField(11)
  String? remoteId;

  LocalRecording({
    required this.id,
    required this.filePath,
    this.prospectId,
    this.prospectName,
    required this.createdAt,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.uploadStatus = RecordingUploadStatus.pending,
    this.uploadError,
    this.uploadAttempts = 0,
    this.lastUploadAttempt,
    this.remoteId,
  });

  /// Get duration as Duration object
  Duration get duration => Duration(seconds: durationSeconds);

  /// Get formatted duration string
  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Check if recording is ready for upload
  bool get canUpload =>
      uploadStatus == RecordingUploadStatus.pending ||
      uploadStatus == RecordingUploadStatus.failed;

  /// Check if upload is in progress
  bool get isUploading => uploadStatus == RecordingUploadStatus.uploading;

  /// Check if successfully uploaded
  bool get isUploaded => uploadStatus == RecordingUploadStatus.uploaded;

  /// Update for copy
  LocalRecording copyWith({
    RecordingUploadStatus? uploadStatus,
    String? uploadError,
    int? uploadAttempts,
    DateTime? lastUploadAttempt,
    String? remoteId,
  }) {
    return LocalRecording(
      id: id,
      filePath: filePath,
      prospectId: prospectId,
      prospectName: prospectName,
      createdAt: createdAt,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      lastUploadAttempt: lastUploadAttempt ?? this.lastUploadAttempt,
      remoteId: remoteId ?? this.remoteId,
    );
  }
}


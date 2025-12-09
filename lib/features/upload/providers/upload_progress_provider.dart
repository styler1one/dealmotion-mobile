import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Upload progress state for a single recording
class UploadProgressState {
  final String? currentRecordingId;
  final double progress; // 0.0 - 1.0
  final bool isUploading;
  final String? errorMessage;

  const UploadProgressState({
    this.currentRecordingId,
    this.progress = 0.0,
    this.isUploading = false,
    this.errorMessage,
  });

  UploadProgressState copyWith({
    String? currentRecordingId,
    double? progress,
    bool? isUploading,
    String? errorMessage,
  }) {
    return UploadProgressState(
      currentRecordingId: currentRecordingId ?? this.currentRecordingId,
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for upload progress
class UploadProgressNotifier extends StateNotifier<UploadProgressState> {
  UploadProgressNotifier() : super(const UploadProgressState());

  /// Start upload for a recording
  void startUpload(String recordingId) {
    state = UploadProgressState(
      currentRecordingId: recordingId,
      progress: 0.0,
      isUploading: true,
    );
  }

  /// Update progress (0.0 - 1.0)
  void updateProgress(double progress) {
    if (state.isUploading) {
      state = state.copyWith(progress: progress);
    }
  }

  /// Complete upload
  void completeUpload() {
    state = state.copyWith(
      progress: 1.0,
      isUploading: false,
    );
    // Reset after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (state.progress >= 1.0 && !state.isUploading) {
        reset();
      }
    });
  }

  /// Fail upload
  void failUpload(String error) {
    state = state.copyWith(
      isUploading: false,
      errorMessage: error,
    );
  }

  /// Reset state
  void reset() {
    state = const UploadProgressState();
  }
}

/// Global upload progress provider
final uploadProgressProvider =
    StateNotifierProvider<UploadProgressNotifier, UploadProgressState>(
  (ref) => UploadProgressNotifier(),
);

/// Convenience getter for current progress by recording ID
final uploadProgressForRecording = Provider.family<double?, String>((ref, recordingId) {
  final state = ref.watch(uploadProgressProvider);
  if (state.currentRecordingId == recordingId && state.isUploading) {
    return state.progress;
  }
  return null;
});


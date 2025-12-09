import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/local_recording.dart';
import '../data/local_recording_repository.dart';

/// State for local recordings
class LocalRecordingsState {
  final List<LocalRecording> recordings;
  final bool isLoading;
  final String? error;

  const LocalRecordingsState({
    this.recordings = const [],
    this.isLoading = false,
    this.error,
  });

  LocalRecordingsState copyWith({
    List<LocalRecording>? recordings,
    bool? isLoading,
    String? error,
  }) {
    return LocalRecordingsState(
      recordings: recordings ?? this.recordings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get pending recordings count
  int get pendingCount =>
      recordings.where((r) => r.uploadStatus == RecordingUploadStatus.pending).length;

  /// Get uploading recordings count
  int get uploadingCount =>
      recordings.where((r) => r.uploadStatus == RecordingUploadStatus.uploading).length;

  /// Get failed recordings count
  int get failedCount =>
      recordings.where((r) => r.uploadStatus == RecordingUploadStatus.failed).length;

  /// Get uploaded recordings count
  int get uploadedCount =>
      recordings.where((r) => r.uploadStatus == RecordingUploadStatus.uploaded).length;

  /// Check if there are any pending uploads
  bool get hasPendingUploads => pendingCount > 0 || failedCount > 0;
}

/// Notifier for local recordings
class LocalRecordingsNotifier extends StateNotifier<LocalRecordingsState> {
  final LocalRecordingRepository _repository = LocalRecordingRepository.instance;

  LocalRecordingsNotifier() : super(const LocalRecordingsState()) {
    loadRecordings();
  }

  /// Load all recordings
  Future<void> loadRecordings() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.open();
      final recordings = await _repository.getAllRecordings();
      state = state.copyWith(
        recordings: recordings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh recordings
  Future<void> refresh() async {
    await loadRecordings();
  }

  /// Delete a recording
  Future<void> deleteRecording(String id) async {
    try {
      await _repository.deleteRecording(id);
      state = state.copyWith(
        recordings: state.recordings.where((r) => r.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete all uploaded recordings
  Future<int> deleteUploadedRecordings() async {
    try {
      final count = await _repository.deleteUploadedRecordings();
      await loadRecordings();
      return count;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 0;
    }
  }

  /// Update recording status (called by upload service)
  void updateRecordingStatus(String id, RecordingUploadStatus status) {
    final updatedRecordings = state.recordings.map((r) {
      if (r.id == id) {
        return r.copyWith(uploadStatus: status);
      }
      return r;
    }).toList();
    
    state = state.copyWith(recordings: updatedRecordings);
  }
}

/// Provider for local recordings
final localRecordingsProvider =
    StateNotifierProvider<LocalRecordingsNotifier, LocalRecordingsState>((ref) {
  return LocalRecordingsNotifier();
});

/// Provider for pending recordings count (for badge in UI)
final pendingRecordingsCountProvider = Provider<int>((ref) {
  final state = ref.watch(localRecordingsProvider);
  return state.pendingCount + state.failedCount;
});


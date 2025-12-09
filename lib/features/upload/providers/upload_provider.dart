import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/local_recording.dart';
import '../../recording/data/local_recording_repository.dart';
import '../../recording/providers/local_recordings_provider.dart';
import '../services/upload_service.dart';

/// Upload state
class UploadState {
  final bool isUploading;
  final String? currentUploadId;
  final double currentProgress;
  final int totalPending;
  final int uploadedCount;
  final int failedCount;
  final String? lastError;
  final bool hasConnectivity;

  const UploadState({
    this.isUploading = false,
    this.currentUploadId,
    this.currentProgress = 0.0,
    this.totalPending = 0,
    this.uploadedCount = 0,
    this.failedCount = 0,
    this.lastError,
    this.hasConnectivity = true,
  });

  UploadState copyWith({
    bool? isUploading,
    String? currentUploadId,
    double? currentProgress,
    int? totalPending,
    int? uploadedCount,
    int? failedCount,
    String? lastError,
    bool? hasConnectivity,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      currentUploadId: currentUploadId,
      currentProgress: currentProgress ?? this.currentProgress,
      totalPending: totalPending ?? this.totalPending,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      failedCount: failedCount ?? this.failedCount,
      lastError: lastError,
      hasConnectivity: hasConnectivity ?? this.hasConnectivity,
    );
  }

  /// Overall progress (0.0 - 1.0)
  double get overallProgress {
    final total = uploadedCount + failedCount + totalPending;
    if (total == 0) return 0.0;
    return uploadedCount / total;
  }
}

/// Upload notifier
class UploadNotifier extends StateNotifier<UploadState> {
  final UploadService _uploadService = UploadService.instance;
  final LocalRecordingRepository _localRepo = LocalRecordingRepository.instance;
  final Ref _ref;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  UploadNotifier(this._ref) : super(const UploadState()) {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final hasConn = await _uploadService.hasConnectivity();
    state = state.copyWith(hasConnectivity: hasConn);

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConn = results.any((r) => r != ConnectivityResult.none);
      state = state.copyWith(hasConnectivity: hasConn);
      
      // Auto-upload when connectivity restored
      if (hasConn && state.totalPending > 0 && !state.isUploading) {
        uploadAllPending();
      }
    });

    // Update pending count
    await _updateCounts();
  }

  Future<void> _updateCounts() async {
    try {
      await _localRepo.open();
      final recordings = await _localRepo.getAllRecordings();
      
      final pending = recordings.where((r) => 
          r.uploadStatus == RecordingUploadStatus.pending).length;
      final failed = recordings.where((r) => 
          r.uploadStatus == RecordingUploadStatus.failed).length;
      final uploaded = recordings.where((r) => 
          r.uploadStatus == RecordingUploadStatus.uploaded).length;

      state = state.copyWith(
        totalPending: pending + failed,
        uploadedCount: uploaded,
        failedCount: failed,
      );
    } catch (e) {
      // Ignore errors during count update
    }
  }

  /// Upload all pending recordings
  Future<void> uploadAllPending() async {
    if (state.isUploading) return;
    if (!state.hasConnectivity) {
      state = state.copyWith(lastError: 'No network connection');
      return;
    }

    state = state.copyWith(
      isUploading: true,
      uploadedCount: 0,
      failedCount: 0,
      lastError: null,
    );

    await _updateCounts();

    try {
      await _uploadService.uploadAllPending(
        onProgress: (recordingId, progress) {
          state = state.copyWith(
            currentUploadId: recordingId,
            currentProgress: progress,
          );
        },
        onComplete: (recordingId, result) {
          if (result.success) {
            state = state.copyWith(
              uploadedCount: state.uploadedCount + 1,
              totalPending: state.totalPending - 1,
            );
          } else {
            state = state.copyWith(
              failedCount: state.failedCount + 1,
              totalPending: state.totalPending - 1,
              lastError: result.error,
            );
          }
          
          // Refresh local recordings list
          _ref.read(localRecordingsProvider.notifier).refresh();
        },
      );
    } finally {
      state = state.copyWith(
        isUploading: false,
        currentUploadId: null,
        currentProgress: 0.0,
      );
      await _updateCounts();
    }
  }

  /// Upload a single recording
  Future<void> uploadSingle(LocalRecording recording) async {
    if (state.isUploading) return;
    if (!state.hasConnectivity) {
      state = state.copyWith(lastError: 'No network connection');
      return;
    }

    state = state.copyWith(
      isUploading: true,
      currentUploadId: recording.id,
      currentProgress: 0.0,
      lastError: null,
    );

    try {
      final result = await _uploadService.uploadRecording(
        recording,
        onProgress: (progress) {
          state = state.copyWith(currentProgress: progress);
        },
      );

      if (result.success) {
        state = state.copyWith(uploadedCount: state.uploadedCount + 1);
      } else {
        state = state.copyWith(
          failedCount: state.failedCount + 1,
          lastError: result.error,
        );
      }
      
      // Refresh local recordings list
      _ref.read(localRecordingsProvider.notifier).refresh();
    } finally {
      state = state.copyWith(
        isUploading: false,
        currentUploadId: null,
        currentProgress: 0.0,
      );
      await _updateCounts();
    }
  }

  /// Retry failed uploads
  Future<void> retryFailed() async {
    if (state.isUploading) return;

    state = state.copyWith(
      isUploading: true,
      failedCount: 0,
      lastError: null,
    );

    try {
      await _uploadService.retryFailed(
        onProgress: (recordingId, progress) {
          state = state.copyWith(
            currentUploadId: recordingId,
            currentProgress: progress,
          );
        },
        onComplete: (recordingId, result) {
          if (result.success) {
            state = state.copyWith(uploadedCount: state.uploadedCount + 1);
          } else {
            state = state.copyWith(
              failedCount: state.failedCount + 1,
              lastError: result.error,
            );
          }
          _ref.read(localRecordingsProvider.notifier).refresh();
        },
      );
    } finally {
      state = state.copyWith(
        isUploading: false,
        currentUploadId: null,
        currentProgress: 0.0,
      );
      await _updateCounts();
    }
  }

  /// Clear last error
  void clearError() {
    state = state.copyWith(lastError: null);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// Upload provider
final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref);
});

/// Provider for checking if there are pending uploads
final hasPendingUploadsProvider = Provider<bool>((ref) {
  final state = ref.watch(uploadProvider);
  return state.totalPending > 0;
});

/// Provider for connectivity status
final hasConnectivityProvider = Provider<bool>((ref) {
  return ref.watch(uploadProvider).hasConnectivity;
});


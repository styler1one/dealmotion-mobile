import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_recording_repository.dart';
import '../services/recording_service.dart';
import '../services/foreground_service.dart';

/// Recording state enum
enum RecordingStatus {
  idle,
  recording,
  paused,
  stopped,
  error,
}

/// Recording state
class RecordingState {
  final RecordingStatus status;
  final Duration duration;
  final String? filePath;
  final String? errorMessage;
  final String? prospectId;
  final String? prospectName;
  final double amplitude;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.duration = Duration.zero,
    this.filePath,
    this.errorMessage,
    this.prospectId,
    this.prospectName,
    this.amplitude = 0.0,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    Duration? duration,
    String? filePath,
    String? errorMessage,
    String? prospectId,
    String? prospectName,
    double? amplitude,
  }) {
    return RecordingState(
      status: status ?? this.status,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage,
      prospectId: prospectId ?? this.prospectId,
      prospectName: prospectName ?? this.prospectName,
      amplitude: amplitude ?? this.amplitude,
    );
  }

  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get isStopped => status == RecordingStatus.stopped;
  bool get isIdle => status == RecordingStatus.idle;
  bool get hasError => status == RecordingStatus.error;
  bool get isActive => isRecording || isPaused;
}

/// Recording notifier
class RecordingNotifier extends StateNotifier<RecordingState> {
  final RecordingService _recordingService = RecordingService.instance;
  final RecordingForegroundService _foregroundService = RecordingForegroundService.instance;
  Timer? _timer;
  StreamSubscription<double>? _amplitudeSubscription;

  RecordingNotifier() : super(const RecordingState()) {
    _initializeForegroundService();
  }

  Future<void> _initializeForegroundService() async {
    await _foregroundService.initialize();
  }

  /// Initialize with prospect info
  void initialize({String? prospectId, String? prospectName}) {
    state = RecordingState(
      prospectId: prospectId,
      prospectName: prospectName,
    );
  }

  /// Start recording
  Future<void> startRecording() async {
    try {
      // Request permission first
      final hasPermission = await _recordingService.hasPermission();
      if (!hasPermission) {
        final granted = await _recordingService.requestPermission();
        if (!granted) {
          state = state.copyWith(
            status: RecordingStatus.error,
            errorMessage: 'Microphone permission is required to record',
          );
          return;
        }
      }

      // Initialize and start
      await _recordingService.initialize();
      final filePath = await _recordingService.startRecording(
        prospectId: state.prospectId,
      );

      state = state.copyWith(
        status: RecordingStatus.recording,
        duration: Duration.zero,
        filePath: filePath,
      );

      // Start foreground service for background recording
      await _foregroundService.startService(
        prospectName: state.prospectName,
      );

      _startTimer();
      _startAmplitudeListener();
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (state.isRecording) {
      try {
        await _recordingService.pauseRecording();
        _stopTimer();
        state = state.copyWith(status: RecordingStatus.paused);
      } catch (e) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (state.isPaused) {
      try {
        await _recordingService.resumeRecording();
        state = state.copyWith(status: RecordingStatus.recording);
        _startTimer();
      } catch (e) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Stop recording
  Future<String?> stopRecording() async {
    final duration = state.duration;
    _stopTimer();
    _stopAmplitudeListener();

    try {
      final filePath = await _recordingService.stopRecording();
      
      // Stop foreground service
      await _foregroundService.stopService();

      // Save to local storage for offline support
      if (filePath != null) {
        await LocalRecordingRepository.instance.saveRecording(
          filePath: filePath,
          durationSeconds: duration.inSeconds,
          prospectId: state.prospectId,
          prospectName: state.prospectName,
        );
      }

      state = state.copyWith(
        status: RecordingStatus.stopped,
        filePath: filePath,
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Reset state
  void reset() {
    _stopTimer();
    _stopAmplitudeListener();
    // Stop foreground service in background (fire-and-forget)
    _foregroundService.stopService();
    state = RecordingState(
      prospectId: state.prospectId,
      prospectName: state.prospectName,
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(
      status: RecordingStatus.idle,
      errorMessage: null,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRecording) {
        state = state.copyWith(
          duration: state.duration + const Duration(seconds: 1),
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startAmplitudeListener() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recordingService.amplitudeStream.listen((amp) {
      if (state.isRecording) {
        state = state.copyWith(amplitude: amp);
      }
    });
  }

  void _stopAmplitudeListener() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _stopAmplitudeListener();
    super.dispose();
  }
}

/// Recording provider
final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  return RecordingNotifier();
});

/// Recording service provider
final recordingServiceProvider = Provider<RecordingService>((ref) {
  return RecordingService.instance;
});

import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';

/// Service for handling audio recording
class RecordingService {
  static RecordingService? _instance;
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;
  String? _currentFilePath;
  StreamController<double>? _amplitudeController;
  Timer? _amplitudeTimer;

  RecordingService._();

  static RecordingService get instance {
    _instance ??= RecordingService._();
    return _instance!;
  }

  /// Stream of amplitude values for waveform visualization
  Stream<double> get amplitudeStream {
    _amplitudeController ??= StreamController<double>.broadcast();
    return _amplitudeController!.stream;
  }

  /// Check if recording is active
  bool get isRecording => _recorder.isRecording;

  /// Check if recording is paused
  bool get isPaused => _recorder.isPaused;

  /// Current file path
  String? get currentFilePath => _currentFilePath;

  /// Initialize the recorder
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(
      const Duration(milliseconds: 100),
    );
    _isInitialized = true;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start recording
  Future<String> startRecording({String? prospectId}) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check permission
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Microphone permission denied');
      }
    }

    // Generate file path
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final uuid = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'recording_${timestamp}_$uuid.m4a';
    _currentFilePath = '${recordingsDir.path}/$fileName';

    // Configure recorder
    await _recorder.startRecorder(
      toFile: _currentFilePath,
      codec: Codec.aacMP4,
      sampleRate: AppConfig.sampleRate,
      bitRate: AppConfig.bitRate,
    );

    // Start amplitude monitoring
    _startAmplitudeMonitoring();

    return _currentFilePath!;
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (_recorder.isRecording) {
      await _recorder.pauseRecorder();
      _stopAmplitudeMonitoring();
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (_recorder.isPaused) {
      await _recorder.resumeRecorder();
      _startAmplitudeMonitoring();
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    _stopAmplitudeMonitoring();
    
    if (_recorder.isRecording || _recorder.isPaused) {
      final path = await _recorder.stopRecorder();
      final filePath = _currentFilePath;
      _currentFilePath = null;
      return filePath ?? path;
    }
    
    return null;
  }

  /// Get recording duration
  Duration? get currentDuration {
    // This would need to be tracked separately with a timer
    // as flutter_sound doesn't provide a direct way to get duration during recording
    return null;
  }

  /// Delete a recording file
  Future<void> deleteRecording(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get all local recordings
  Future<List<File>> getLocalRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${directory.path}/recordings');
    
    if (!await recordingsDir.exists()) {
      return [];
    }

    final files = await recordingsDir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.m4a'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Most recent first
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  void _startAmplitudeMonitoring() {
    _amplitudeController ??= StreamController<double>.broadcast();
    
    _recorder.onProgress?.listen((event) {
      final decibels = event.decibels ?? 0;
      // Normalize decibels to 0-1 range (assuming -60 to 0 dB range)
      final normalized = ((decibels + 60) / 60).clamp(0.0, 1.0);
      _amplitudeController?.add(normalized);
    });
  }

  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    _stopAmplitudeMonitoring();
    await _amplitudeController?.close();
    _amplitudeController = null;
    
    if (_isInitialized) {
      await _recorder.closeRecorder();
      _isInitialized = false;
    }
  }
}


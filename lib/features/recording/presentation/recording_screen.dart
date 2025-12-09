import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/recording_provider.dart';
import '../providers/local_recordings_provider.dart';
import '../../upload/services/background_upload_service.dart';

/// Recording screen - main recording interface
class RecordingScreen extends ConsumerStatefulWidget {
  final String? prospectId;
  final String? prospectName;

  const RecordingScreen({
    super.key,
    this.prospectId,
    this.prospectName,
  });

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    // Initialize recording with prospect info
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordingProvider.notifier).initialize(
            prospectId: widget.prospectId,
            prospectName: widget.prospectName,
          );
    });

    // Pulse animation for recording indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordButton() async {
    final recordingNotifier = ref.read(recordingProvider.notifier);
    final state = ref.read(recordingProvider);

    HapticFeedback.mediumImpact();

    if (state.isIdle) {
      // Show consent reminder before starting recording
      _showConsentReminder(() async {
        await recordingNotifier.startRecording();
      });
    } else if (state.isRecording || state.isPaused) {
      final filePath = await recordingNotifier.stopRecording();
      if (filePath != null && mounted) {
        _showSaveDialog(filePath);
      }
    }
  }

  void _showConsentReminder(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.record_voice_over_rounded,
            color: AppTheme.warningAmber,
            size: 32,
          ),
        ),
        title: const Text('Recording Consent'),
        content: const Text(
          'Please make sure you have permission from all participants before recording this conversation.\n\n'
          '"Do you mind if I record this meeting for my notes?"',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('I Have Consent'),
          ),
        ],
      ),
    );
  }

  void _handlePauseResume() {
    final recordingNotifier = ref.read(recordingProvider.notifier);
    final state = ref.read(recordingProvider);

    HapticFeedback.lightImpact();

    if (state.isRecording) {
      recordingNotifier.pauseRecording();
    } else if (state.isPaused) {
      recordingNotifier.resumeRecording();
    }
  }

  void _showSaveDialog(String filePath) {
    final state = ref.read(recordingProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Success icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Recording Saved!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Details
              Text(
                'Duration: ${_formatDuration(state.duration)}',
                style: TextStyle(color: AppTheme.slate500),
                textAlign: TextAlign.center,
              ),
              if (widget.prospectName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Prospect: ${widget.prospectName}',
                  style: TextStyle(color: AppTheme.slate500),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your recording will be uploaded and analyzed automatically.',
                        style: TextStyle(
                          color: AppTheme.slate600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Done button
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  ref.read(recordingProvider.notifier).reset();
                  // Refresh recordings list
                  ref.read(localRecordingsProvider.notifier).refresh();
                  // Trigger upload in background
                  triggerImmediateUpload();
                  context.pop();
                },
                child: const Text('Done'),
              ),
              const SizedBox(height: 8),

              // New recording button
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(recordingProvider.notifier).reset();
                },
                child: const Text('Start New Recording'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Recording?'),
        content: const Text(
          'Are you sure you want to discard this recording? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(recordingProvider.notifier).reset();
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final isActive = recordingState.isActive;

    return Scaffold(
      backgroundColor: isActive ? AppTheme.slate900 : AppTheme.slate50,
      appBar: AppBar(
        backgroundColor: isActive ? AppTheme.slate900 : null,
        foregroundColor: isActive ? Colors.white : null,
        elevation: 0,
        title: Text(
          widget.prospectName ?? 'New Recording',
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.slate900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (recordingState.isActive) {
              _showDiscardDialog();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Recording visualization
              if (isActive) ...[
                // Animated waves
                SizedBox(
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(double.infinity, 120),
                        painter: WaveformPainter(
                          animation: _waveController.value,
                          isRecording: recordingState.isRecording,
                          color: recordingState.isPaused
                              ? AppTheme.warningAmber
                              : AppTheme.primaryBlue,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Recording indicator
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 16 + (_pulseController.value * 4),
                      height: 16 + (_pulseController.value * 4),
                      decoration: BoxDecoration(
                        color: recordingState.isPaused
                            ? AppTheme.warningAmber
                            : AppTheme.errorRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (recordingState.isPaused
                                    ? AppTheme.warningAmber
                                    : AppTheme.errorRed)
                                .withOpacity(0.5 - _pulseController.value * 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Duration
                Text(
                  _formatDuration(recordingState.duration),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 8),

                // Status text
                Text(
                  recordingState.isPaused ? 'Paused' : 'Recording...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.slate400,
                      ),
                ),
              ] else ...[
                // Pre-recording state
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 60,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Ready to Record',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to start\nrecording your meeting',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate500,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(flex: 3),

              // Recording controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isActive) ...[
                    // Pause/Resume button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.slate600,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _handlePauseResume,
                        icon: Icon(
                          recordingState.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        iconSize: 32,
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],

                  // Main record/stop button
                  GestureDetector(
                    onTap: _handleRecordButton,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isActive
                              ? [AppTheme.errorRed, AppTheme.errorRed]
                              : [AppTheme.primaryBlue, AppTheme.accentPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isActive
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryBlue)
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        isActive ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Info text
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppTheme.slate500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recording continues in background',
                        style: TextStyle(
                          color: AppTheme.slate500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for waveform visualization
class WaveformPainter extends CustomPainter {
  final double animation;
  final bool isRecording;
  final Color color;

  WaveformPainter({
    required this.animation,
    required this.isRecording,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    final waveCount = 3;

    for (int wave = 0; wave < waveCount; wave++) {
      final waveOffset = wave * 0.3;
      final opacity = 1.0 - (wave * 0.25);
      paint.color = color.withOpacity(opacity * 0.6);

      path.reset();
      for (double x = 0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;
        final phase = (animation + waveOffset) * 2 * math.pi;
        final amplitude = isRecording
            ? 20.0 + (math.sin(phase + normalizedX * 4) * 10)
            : 10.0;
        final y = centerY +
            math.sin((normalizedX * 4 * math.pi) + phase) * amplitude;

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.color != color;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/local_recording.dart';
import '../../recording/providers/local_recordings_provider.dart';
import '../../upload/services/background_upload_service.dart';

/// Recording history screen - shows all local and uploaded recordings
class RecordingsHistoryScreen extends ConsumerStatefulWidget {
  const RecordingsHistoryScreen({super.key});

  @override
  ConsumerState<RecordingsHistoryScreen> createState() => _RecordingsHistoryScreenState();
}

class _RecordingsHistoryScreenState extends ConsumerState<RecordingsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for upload status changes and refresh
    UploadProgressTracker.instance.uploadChangeCounter.addListener(_onUploadChange);
  }

  @override
  void dispose() {
    UploadProgressTracker.instance.uploadChangeCounter.removeListener(_onUploadChange);
    super.dispose();
  }

  void _onUploadChange() {
    // Refresh the recordings list when upload status changes
    ref.read(localRecordingsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final recordingsState = ref.watch(localRecordingsProvider);
    final hasFailedUploads = recordingsState.recordings
        .any((r) => r.uploadStatus == RecordingUploadStatus.failed);
    final hasPendingUploads = recordingsState.recordings
        .any((r) => r.uploadStatus == RecordingUploadStatus.pending);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.prospects),
        ),
        title: const Text('Recording History'),
        actions: [
          if (hasFailedUploads || hasPendingUploads)
            ValueListenableBuilder<bool>(
              valueListenable: UploadProgressTracker.instance.isUploading,
              builder: (context, isUploading, _) {
                if (isUploading) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  tooltip: 'Upload All',
                  onPressed: () async {
                    // Retry all failed and pending uploads
                    for (final recording in recordingsState.recordings) {
                      if (recording.uploadStatus == RecordingUploadStatus.failed) {
                        ref.read(localRecordingsProvider.notifier).updateRecordingStatus(
                          recording.id,
                          RecordingUploadStatus.pending,
                        );
                      }
                    }
                    // Trigger upload
                    await triggerImmediateUpload();
                    // Refresh list
                    ref.read(localRecordingsProvider.notifier).refresh();
                  },
                );
              },
            ),
        ],
      ),
      body: _buildBody(context, ref, recordingsState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, LocalRecordingsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load recordings',
              style: TextStyle(color: AppTheme.slate500),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(localRecordingsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final recordings = state.recordings;

    if (recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_off_outlined,
              size: 64,
              color: AppTheme.slate300,
            ),
            const SizedBox(height: 16),
            Text(
              'No recordings yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your recorded meetings will appear here',
              style: TextStyle(color: AppTheme.slate400),
            ),
          ],
        ),
      );
    }

    // Sort by date (newest first)
    final sortedRecordings = List<LocalRecording>.from(recordings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Group by date
    final grouped = <String, List<LocalRecording>>{};
    for (final recording in sortedRecordings) {
      final dateKey = _formatDateKey(recording.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(recording);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final dayRecordings = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.slate500,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...dayRecordings.map(
              (recording) => _RecordingTile(recording: recording),
            ),
          ],
        );
      },
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final recordingDate = DateTime(date.year, date.month, date.day);

    if (recordingDate == today) {
      return 'Today';
    } else if (recordingDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
}

class _RecordingTile extends ConsumerWidget {
  final LocalRecording recording;

  const _RecordingTile({required this.recording});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showRecordingDetails(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: recording.uploadStatus == RecordingUploadStatus.uploading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _getStatusIcon(),
                            color: _getStatusColor(),
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recording.prospectName ?? 'Quick Recording',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.slate400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recording.formattedDuration,
                              style: TextStyle(
                                color: AppTheme.slate500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('HH:mm').format(recording.createdAt),
                              style: TextStyle(
                                color: AppTheme.slate400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Upload status badge
                  _buildStatusBadge(),
                ],
              ),
            ),
            // Progress bar for uploading recordings
            if (recording.uploadStatus == RecordingUploadStatus.uploading)
              ValueListenableBuilder<Map<String, double>>(
                valueListenable: UploadProgressTracker.instance.progressMap,
                builder: (context, progressMap, _) {
                  final progress = progressMap[recording.id] ?? 0.0;
                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: AppTheme.slate200,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    String text;
    Color color;

    switch (recording.uploadStatus) {
      case RecordingUploadStatus.pending:
        text = 'Pending';
        color = AppTheme.warningAmber;
      case RecordingUploadStatus.uploading:
        text = 'Uploading';
        color = AppTheme.primaryBlue;
      case RecordingUploadStatus.uploaded:
        text = 'Uploaded';
        color = AppTheme.successGreen;
      case RecordingUploadStatus.failed:
        text = 'Failed';
        color = AppTheme.errorRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (recording.uploadStatus) {
      case RecordingUploadStatus.pending:
        return AppTheme.warningAmber;
      case RecordingUploadStatus.uploading:
        return AppTheme.primaryBlue;
      case RecordingUploadStatus.uploaded:
        return AppTheme.successGreen;
      case RecordingUploadStatus.failed:
        return AppTheme.errorRed;
    }
  }

  IconData _getStatusIcon() {
    switch (recording.uploadStatus) {
      case RecordingUploadStatus.pending:
        return Icons.cloud_queue;
      case RecordingUploadStatus.uploading:
        return Icons.cloud_upload_outlined;
      case RecordingUploadStatus.uploaded:
        return Icons.cloud_done;
      case RecordingUploadStatus.failed:
        return Icons.cloud_off;
    }
  }

  void _showRecordingDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
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

              // Title
              Text(
                recording.prospectName ?? 'Quick Recording',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow(
                Icons.access_time,
                'Duration',
                recording.formattedDuration,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.calendar_today,
                'Recorded',
                DateFormat('MMM d, yyyy • HH:mm').format(recording.createdAt),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.cloud_outlined,
                'Status',
                _getStatusText(),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.storage,
                'Size',
                recording.formattedFileSize,
              ),
              const SizedBox(height: 24),

              // Actions
              if (recording.uploadStatus == RecordingUploadStatus.failed) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Trigger retry by setting status to pending
                    ref.read(localRecordingsProvider.notifier).updateRecordingStatus(
                          recording.id,
                          RecordingUploadStatus.pending,
                        );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Upload'),
                ),
                const SizedBox(height: 8),
              ],

              // Delete button
              TextButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                label: const Text(
                  'Delete Recording',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.slate400),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: AppTheme.slate500),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _getStatusText() {
    switch (recording.uploadStatus) {
      case RecordingUploadStatus.pending:
        return 'Waiting to upload';
      case RecordingUploadStatus.uploading:
        return 'Uploading...';
      case RecordingUploadStatus.uploaded:
        return 'Uploaded successfully';
      case RecordingUploadStatus.failed:
        return 'Upload failed';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: const Text(
          'This will permanently delete this recording. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              await ref.read(localRecordingsProvider.notifier).deleteRecording(recording.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

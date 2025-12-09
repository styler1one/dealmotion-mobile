import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/followup_model.dart';
import '../providers/followup_provider.dart';

/// Followup Detail Screen - View meeting analysis
class FollowupDetailScreen extends ConsumerWidget {
  final String followupId;

  const FollowupDetailScreen({
    super.key,
    required this.followupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followupAsync = ref.watch(followupDetailProvider(followupId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      body: followupAsync.when(
        data: (followup) {
          if (followup == null) {
            return _ErrorView(
              message: 'Analysis not found',
              onRetry: () => ref.refresh(followupDetailProvider(followupId)),
            );
          }
          return _FollowupContent(followup: followup, isDark: isDark);
        },
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.refresh(followupDetailProvider(followupId)),
        ),
      ),
    );
  }
}

/// Followup content view
class _FollowupContent extends StatelessWidget {
  final Followup followup;
  final bool isDark;

  const _FollowupContent({
    required this.followup,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          backgroundColor: isDark ? AppTheme.slate900 : Colors.white,
          pinned: true,
          expandedHeight: 140,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareAnalysis(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 56),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Analysis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.warningAmber,
                  ),
                ),
                Text(
                  followup.displayTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.warningAmber.withValues(alpha: 0.1),
                    isDark ? AppTheme.slate900 : Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Status banner if processing
        if (followup.isProcessing)
          SliverToBoxAdapter(
            child: _ProcessingBanner(status: followup.status),
          ),

        // Failed banner
        if (followup.isFailed)
          SliverToBoxAdapter(
            child: _FailedBanner(message: followup.errorMessage),
          ),

        // Meeting info header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _MeetingHeader(followup: followup, isDark: isDark),
          ),
        ),

        // Summary/Executive summary
        if (followup.summary != null && followup.summary!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ContentCard(
                icon: Icons.summarize,
                iconColor: AppTheme.primaryBlue,
                title: 'Executive Summary',
                content: followup.summary!,
                isDark: isDark,
              ),
            ),
          ),

        // Full content sections
        if (followup.fullContent != null && followup.fullContent!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _FullContentView(
                content: followup.fullContent!,
                isDark: isDark,
              ),
            ),
          ),

        // Transcript section (collapsed)
        if (followup.transcriptionText != null &&
            followup.transcriptionText!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TranscriptSection(
                transcript: followup.transcriptionText!,
                isDark: isDark,
              ),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _shareAnalysis(BuildContext context) {
    final text = '''
Meeting Analysis: ${followup.displayTitle}
${followup.meetingDate != null ? DateFormat('d MMM yyyy').format(followup.meetingDate!) : ''}

${followup.summary ?? 'Analysis in progress...'}

Generated by DealMotion
''';
    Share.share(text, subject: 'Meeting Analysis: ${followup.displayTitle}');
  }
}

/// Meeting header
class _MeetingHeader extends StatelessWidget {
  final Followup followup;
  final bool isDark;

  const _MeetingHeader({
    required this.followup,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.slate800 : AppTheme.slate200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic,
                    size: 24,
                    color: AppTheme.warningAmber,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      followup.displayTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (followup.meetingDate != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM yyyy')
                                .format(followup.meetingDate!),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                        if (followup.formattedDuration != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            followup.formattedDuration!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: followup.status),
            ],
          ),
          if (followup.companyName != null) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? AppTheme.slate800 : AppTheme.slate200,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: AppTheme.slate400,
                ),
                const SizedBox(width: 8),
                Text(
                  followup.companyName!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Status badge
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'completed':
        color = AppTheme.successGreen;
        label = 'Complete';
        icon = Icons.check_circle;
        break;
      case 'summarizing':
        color = AppTheme.warningAmber;
        label = 'Analyzing';
        icon = Icons.psychology;
        break;
      case 'transcribing':
        color = AppTheme.primaryBlue;
        label = 'Transcribing';
        icon = Icons.hearing;
        break;
      case 'processing':
      case 'pending':
        color = AppTheme.primaryBlue;
        label = 'Processing';
        icon = Icons.hourglass_empty;
        break;
      case 'failed':
        color = AppTheme.errorRed;
        label = 'Failed';
        icon = Icons.error;
        break;
      default:
        color = AppTheme.slate500;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Content card
class _ContentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;
  final bool isDark;

  const _ContentCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.slate800 : AppTheme.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.slate900,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy, size: 18, color: AppTheme.slate400),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? AppTheme.slate300 : AppTheme.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full content view with sections
class _FullContentView extends StatelessWidget {
  final String content;
  final bool isDark;

  const _FullContentView({
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        IconData icon;
        Color color;
        final title = section['title']?.toLowerCase() ?? '';

        if (title.contains('key') || title.contains('insight')) {
          icon = Icons.lightbulb;
          color = AppTheme.warningAmber;
        } else if (title.contains('next') || title.contains('action')) {
          icon = Icons.arrow_forward;
          color = AppTheme.successGreen;
        } else if (title.contains('decision') || title.contains('agreement')) {
          icon = Icons.handshake;
          color = AppTheme.primaryBlue;
        } else if (title.contains('concern') || title.contains('risk')) {
          icon = Icons.warning;
          color = AppTheme.errorRed;
        } else if (title.contains('coach') || title.contains('feedback')) {
          icon = Icons.school;
          color = AppTheme.accentPurple;
        } else {
          icon = Icons.article;
          color = AppTheme.slate500;
        }

        return _ContentCard(
          icon: icon,
          iconColor: color,
          title: section['title'] ?? 'Details',
          content: section['content'] ?? '',
          isDark: isDark,
        );
      }).toList(),
    );
  }

  List<Map<String, String>> _parseSections(String content) {
    final sections = <Map<String, String>>[];
    final lines = content.split('\n');
    String currentTitle = 'Details';
    StringBuffer currentContent = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ') || line.startsWith('# ')) {
        if (currentContent.isNotEmpty) {
          sections.add({
            'title': currentTitle,
            'content': currentContent.toString().trim(),
          });
        }
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
        currentContent = StringBuffer();
      } else {
        currentContent.writeln(line);
      }
    }

    if (currentContent.isNotEmpty) {
      sections.add({
        'title': currentTitle,
        'content': currentContent.toString().trim(),
      });
    }

    return sections.isEmpty
        ? [{'title': 'Details', 'content': content}]
        : sections;
  }
}

/// Transcript section (collapsible)
class _TranscriptSection extends StatefulWidget {
  final String transcript;
  final bool isDark;

  const _TranscriptSection({
    required this.transcript,
    required this.isDark,
  });

  @override
  State<_TranscriptSection> createState() => _TranscriptSectionState();
}

class _TranscriptSectionState extends State<_TranscriptSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? AppTheme.slate800 : AppTheme.slate200,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.slate500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.description,
                      color: AppTheme.slate500,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Full Transcript',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : AppTheme.slate900,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.slate400,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.isDark ? AppTheme.slate800 : AppTheme.slate200,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.transcript));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transcript copied'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.transcript,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.8,
                      color: widget.isDark
                          ? AppTheme.slate400
                          : AppTheme.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Processing banner
class _ProcessingBanner extends StatelessWidget {
  final String status;

  const _ProcessingBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    String message;
    switch (status) {
      case 'transcribing':
        message = 'Converting audio to text...';
        break;
      case 'summarizing':
        message = 'AI is analyzing the conversation...';
        break;
      default:
        message = 'Processing your recording...';
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis in Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Failed banner
class _FailedBanner extends StatelessWidget {
  final String? message;

  const _FailedBanner({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: AppTheme.errorRed),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message ?? 'Please try uploading again',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading view
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Error view
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.slate500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


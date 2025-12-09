import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/preparation_model.dart';
import '../providers/preparation_provider.dart';

/// Preparation Detail Screen - View meeting prep
class PreparationDetailScreen extends ConsumerWidget {
  final String preparationId;

  const PreparationDetailScreen({
    super.key,
    required this.preparationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prepAsync = ref.watch(preparationDetailProvider(preparationId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      body: prepAsync.when(
        data: (prep) {
          if (prep == null) {
            return _ErrorView(
              message: 'Preparation not found',
              onRetry: () => ref.refresh(preparationDetailProvider(preparationId)),
            );
          }
          return _PrepContent(preparation: prep, isDark: isDark);
        },
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.refresh(preparationDetailProvider(preparationId)),
        ),
      ),
    );
  }
}

/// Preparation content view
class _PrepContent extends StatelessWidget {
  final Preparation preparation;
  final bool isDark;

  const _PrepContent({
    required this.preparation,
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
              onPressed: () => _sharePrep(context),
            ),
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: () => _startRecording(context),
              tooltip: 'Record Meeting',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 56),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Prep',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.successGreen,
                  ),
                ),
                Text(
                  preparation.companyName,
                  style: TextStyle(
                    fontSize: 18,
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
                    AppTheme.successGreen.withValues(alpha: 0.1),
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
        if (preparation.isProcessing)
          SliverToBoxAdapter(
            child: _ProcessingBanner(),
          ),

        // Failed banner
        if (preparation.isFailed)
          SliverToBoxAdapter(
            child: _FailedBanner(),
          ),

        // Meeting info header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _MeetingHeader(preparation: preparation, isDark: isDark),
          ),
        ),

        // Brief section
        if (preparation.brief != null && preparation.brief!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ContentCard(
                icon: Icons.lightbulb,
                iconColor: AppTheme.warningAmber,
                title: 'Brief',
                content: preparation.brief!,
                isDark: isDark,
              ),
            ),
          ),

        // Full content sections
        if (preparation.fullContent != null &&
            preparation.fullContent!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _FullContentView(
                content: preparation.fullContent!,
                isDark: isDark,
              ),
            ),
          ),

        // User notes
        if (preparation.userNotes != null &&
            preparation.userNotes!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ContentCard(
                icon: Icons.note,
                iconColor: AppTheme.slate500,
                title: 'Your Notes',
                content: preparation.userNotes!,
                isDark: isDark,
              ),
            ),
          ),

        // Record meeting CTA
        if (preparation.isCompleted)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _RecordMeetingCTA(
                onTap: () => _startRecording(context),
              ),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _sharePrep(BuildContext context) {
    final text = '''
Meeting Prep: ${preparation.companyName}
Type: ${preparation.meetingType.displayName}

${preparation.brief ?? 'No brief available'}

Generated by DealMotion
''';
    Share.share(text, subject: 'Meeting Prep: ${preparation.companyName}');
  }

  void _startRecording(BuildContext context) {
    context.push(
      '${AppRoutes.recording}?prospectId=${preparation.prospectId}&prospectName=${Uri.encodeComponent(preparation.companyName)}',
    );
  }
}

/// Meeting header with type badge
class _MeetingHeader extends StatelessWidget {
  final Preparation preparation;
  final bool isDark;

  const _MeetingHeader({
    required this.preparation,
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
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    preparation.companyName.isNotEmpty
                        ? preparation.companyName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preparation.companyName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MeetingTypeBadge(type: preparation.meetingType),
                        const SizedBox(width: 8),
                        _StatusBadge(status: preparation.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Meeting type badge
class _MeetingTypeBadge extends StatelessWidget {
  final MeetingType type;

  const _MeetingTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayName,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryBlue,
        ),
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

    switch (status) {
      case 'completed':
        color = AppTheme.successGreen;
        label = 'Ready';
        break;
      case 'processing':
      case 'pending':
        color = AppTheme.warningAmber;
        label = 'Processing';
        break;
      case 'failed':
        color = AppTheme.errorRed;
        label = 'Failed';
        break;
      default:
        color = AppTheme.slate500;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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

        if (title.contains('talking') || title.contains('point')) {
          icon = Icons.chat_bubble_outline;
          color = AppTheme.primaryBlue;
        } else if (title.contains('question')) {
          icon = Icons.help_outline;
          color = AppTheme.accentPurple;
        } else if (title.contains('strategy') || title.contains('approach')) {
          icon = Icons.track_changes;
          color = AppTheme.successGreen;
        } else if (title.contains('risk') || title.contains('avoid')) {
          icon = Icons.warning_amber;
          color = AppTheme.warningAmber;
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
        ? [
            {'title': 'Details', 'content': content}
          ]
        : sections;
  }
}

/// Record meeting CTA
class _RecordMeetingCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordMeetingCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.errorRed.withValues(alpha: 0.1),
            AppTheme.errorRed.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mic,
            size: 40,
            color: AppTheme.errorRed,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ready for the meeting?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record your meeting for AI analysis',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.mic),
              label: const Text('Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Processing banner
class _ProcessingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                  'Preparation in Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warningAmber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'We\'re crafting your meeting prep...',
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
                  'Preparation Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Please try again or contact support',
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


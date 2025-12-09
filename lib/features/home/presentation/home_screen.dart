import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../followup/domain/followup_model.dart';
import '../../followup/providers/followup_provider.dart';
import '../../meetings/domain/meeting_model.dart';
import '../../meetings/providers/meetings_provider.dart';
import '../../recording/providers/local_recordings_provider.dart';

/// Home screen - dashboard with overview
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Lazy load providers to avoid blocking UI
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(meetingsProvider);
            ref.invalidate(recentFollowupsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'Welcome back',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Stats Card - with Consumer for lazy loading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final meetingsState = ref.watch(meetingsProvider);
                      final pendingRecordings = ref.watch(pendingRecordingsCountProvider);
                      return _QuickStatsCard(
                        todayMeetings: meetingsState.todayMeetings.length,
                        unpreparedMeetings: meetingsState.unpreparedCount,
                        pendingRecordings: pendingRecordings,
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Today's Meetings - with Consumer for lazy loading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final meetingsState = ref.watch(meetingsProvider);
                      return _TodayMeetingsSection(
                        meetings: meetingsState.todayMeetings,
                        isLoading: meetingsState.isLoading,
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Pending Recordings - with Consumer
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, _) {
                    final pendingRecordings = ref.watch(pendingRecordingsCountProvider);
                    if (pendingRecordings <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _PendingRecordingsCard(count: pendingRecordings),
                    );
                  },
                ),
              ),

              // Recent Analysis - with Consumer for lazy loading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final recentFollowups = ref.watch(recentFollowupsProvider);
                      return recentFollowups.when(
                        data: (followups) => _RecentAnalysisSection(
                          followups: followups,
                        ),
                        loading: () => _SectionCard(
                          icon: Icons.analytics,
                          iconColor: AppTheme.warningAmber,
                          title: 'Recent Analysis',
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickActionsSection(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 👋';
    if (hour < 21) return 'Good evening 🌆';
    return 'Good night 🌙';
  }
}

/// Quick stats card
class _QuickStatsCard extends StatelessWidget {
  final int todayMeetings;
  final int unpreparedMeetings;
  final int pendingRecordings;

  const _QuickStatsCard({
    required this.todayMeetings,
    required this.unpreparedMeetings,
    required this.pendingRecordings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: '$todayMeetings',
              label: 'Today',
              icon: Icons.calendar_today,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _StatItem(
              value: '$unpreparedMeetings',
              label: 'Unprepared',
              icon: Icons.warning_amber,
              isWarning: unpreparedMeetings > 0,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _StatItem(
              value: '$pendingRecordings',
              label: 'Pending',
              icon: Icons.upload_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isWarning;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isWarning
                  ? AppTheme.warningAmber
                  : Colors.white.withValues(alpha: 0.8),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isWarning ? AppTheme.warningAmber : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Today's meetings section
class _TodayMeetingsSection extends StatelessWidget {
  final List<Meeting> meetings;
  final bool isLoading;

  const _TodayMeetingsSection({
    required this.meetings,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.calendar_today,
      iconColor: AppTheme.primaryBlue,
      title: "Today's Meetings",
      trailing: meetings.isNotEmpty
          ? TextButton(
              onPressed: () => context.go(AppRoutes.meetings),
              child: const Text('View all'),
            )
          : null,
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : meetings.isEmpty
              ? _EmptyMeetings()
              : Column(
                  children: meetings.take(3).map((meeting) {
                    return _MeetingTile(meeting: meeting);
                  }).toList(),
                ),
    );
  }
}

/// Empty meetings state
class _EmptyMeetings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color: AppTheme.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            'No meetings today',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enjoy your free day!',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Meeting tile for home screen
class _MeetingTile extends StatelessWidget {
  final Meeting meeting;

  const _MeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.go(AppRoutes.meetings);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.slate800 : AppTheme.slate200,
            ),
          ),
        ),
        child: Row(
          children: [
            // Time indicator
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meeting.isNow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Meeting info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.slate900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meeting.prospectName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meeting.prospectName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: meeting.isPrepared
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : AppTheme.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    meeting.isPrepared ? Icons.check : Icons.warning_amber,
                    size: 14,
                    color: meeting.isPrepared
                        ? AppTheme.successGreen
                        : AppTheme.warningAmber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    meeting.isPrepared ? 'Ready' : 'Prep',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: meeting.isPrepared
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending recordings card
class _PendingRecordingsCard extends StatelessWidget {
  final int count;

  const _PendingRecordingsCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.upload_outlined,
      iconColor: AppTheme.warningAmber,
      title: 'Pending Uploads',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.warningAmber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: AppTheme.warningAmber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$count recording${count > 1 ? 's' : ''} waiting to upload',
              style: TextStyle(color: AppTheme.slate600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.recordings),
                child: const Text('View Recordings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent analysis section
class _RecentAnalysisSection extends StatelessWidget {
  final List<Followup> followups;

  const _RecentAnalysisSection({required this.followups});

  @override
  Widget build(BuildContext context) {
    if (followups.isEmpty) {
      return _SectionCard(
        icon: Icons.analytics,
        iconColor: AppTheme.warningAmber,
        title: 'Recent Analysis',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.mic_none, size: 40, color: AppTheme.slate300),
              const SizedBox(height: 12),
              Text(
                'No recordings yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Record your first meeting to get AI insights',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.slate400),
              ),
            ],
          ),
        ),
      );
    }

    return _SectionCard(
      icon: Icons.analytics,
      iconColor: AppTheme.warningAmber,
      title: 'Recent Analysis',
      child: Column(
        children: followups.map((followup) {
          return _FollowupTile(followup: followup);
        }).toList(),
      ),
    );
  }
}

/// Followup tile
class _FollowupTile extends StatelessWidget {
  final Followup followup;

  const _FollowupTile({required this.followup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/followup/${followup.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppTheme.slate800 : AppTheme.slate200,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.mic,
                color: AppTheme.warningAmber,
                size: 20,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.slate900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    followup.meetingDate != null
                        ? DateFormat('d MMM').format(followup.meetingDate!)
                        : 'Recent',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.slate400,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick actions section
class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.flash_on,
      iconColor: AppTheme.successGreen,
      title: 'Quick Actions',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.mic,
                label: 'Record',
                color: AppTheme.errorRed,
                onTap: () => context.push(AppRoutes.recording),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.search,
                label: 'Research',
                color: AppTheme.primaryBlue,
                onTap: () => context.push(AppRoutes.researchCreate),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.edit_note,
                label: 'Prepare',
                color: AppTheme.successGreen,
                onTap: () => context.push(AppRoutes.preparationCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section card wrapper
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.slate800 : AppTheme.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.slate900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppTheme.slate800 : AppTheme.slate200,
          ),
          child,
        ],
      ),
    );
  }
}

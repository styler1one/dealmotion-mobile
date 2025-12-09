import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/meeting_model.dart';
import '../providers/meetings_provider.dart';
import 'widgets/meeting_card.dart';

/// Meetings screen - calendar meetings with prep status
class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final tab = MeetingsTab.values[_tabController.index];
      ref.read(meetingsProvider.notifier).selectTab(tab);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(meetingsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meetings',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.slate900,
                          ),
                        ),
                        if (state.unpreparedCount > 0)
                          Text(
                            '${state.unpreparedCount} unprepared this week',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.warningAmber,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Sync button
                  IconButton(
                    onPressed: state.isSyncing
                        ? null
                        : () => ref.read(meetingsProvider.notifier).syncCalendar(),
                    icon: state.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.refresh,
                            color: AppTheme.slate500,
                          ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.slate800 : AppTheme.slate200,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.slate500,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: [
                  _TabWithBadge(
                    label: 'Today',
                    count: state.todayMeetings.length,
                    isSelected: state.selectedTab == MeetingsTab.today,
                  ),
                  _TabWithBadge(
                    label: 'Tomorrow',
                    count: state.tomorrowMeetings.length,
                    isSelected: state.selectedTab == MeetingsTab.tomorrow,
                  ),
                  _TabWithBadge(
                    label: 'This Week',
                    count: state.weekMeetings.length,
                    isSelected: state.selectedTab == MeetingsTab.week,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                      ? _ErrorView(
                          message: state.error!,
                          onRetry: () =>
                              ref.read(meetingsProvider.notifier).refresh(),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _MeetingsList(
                              meetings: state.todayMeetings,
                              emptyTitle: 'No meetings today',
                              emptySubtitle: 'Enjoy your free day!',
                              onRefresh: () =>
                                  ref.read(meetingsProvider.notifier).refresh(),
                            ),
                            _MeetingsList(
                              meetings: state.tomorrowMeetings,
                              emptyTitle: 'No meetings tomorrow',
                              emptySubtitle: 'Your schedule is clear',
                              onRefresh: () =>
                                  ref.read(meetingsProvider.notifier).refresh(),
                            ),
                            _MeetingsList(
                              meetings: state.weekMeetings,
                              emptyTitle: 'No meetings this week',
                              emptySubtitle:
                                  'Connect your calendar to see meetings',
                              onRefresh: () =>
                                  ref.read(meetingsProvider.notifier).refresh(),
                              groupByDate: true,
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

/// Tab with optional badge
class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;

  const _TabWithBadge({
    required this.label,
    required this.count,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Meetings list
class _MeetingsList extends StatelessWidget {
  final List<Meeting> meetings;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final bool groupByDate;

  const _MeetingsList({
    required this.meetings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.groupByDate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return _EmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    if (groupByDate) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: _buildGroupedList(context),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: meetings.length,
        itemBuilder: (context, index) {
          return MeetingCard(meeting: meetings[index]);
        },
      ),
    );
  }

  List<Widget> _buildGroupedList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final widgets = <Widget>[];
    
    // Group by date
    final grouped = <String, List<Meeting>>{};
    for (final meeting in meetings) {
      final dateKey = DateFormat('yyyy-MM-dd').format(meeting.startTime);
      grouped.putIfAbsent(dateKey, () => []).add(meeting);
    }

    for (final entry in grouped.entries) {
      final date = DateTime.parse(entry.key);
      final dateLabel = _getDateLabel(date);

      // Date header
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Text(
            dateLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.slate400 : AppTheme.slate600,
            ),
          ),
        ),
      );

      // Meetings for this date
      for (final meeting in entry.value) {
        widgets.add(MeetingCard(meeting: meeting));
      }
    }

    widgets.add(const SizedBox(height: 100));
    return widgets;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today - ${DateFormat('EEEE d MMMM').format(date)}';
    } else if (dateOnly == today.add(const Duration(days: 1))) {
      return 'Tomorrow - ${DateFormat('EEEE d MMMM').format(date)}';
    } else {
      return DateFormat('EEEE d MMMM').format(date);
    }
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available,
                size: 48,
                color: AppTheme.primaryBlue.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load meetings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
              ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/prospect_hub_data.dart';
import '../providers/prospect_hub_provider.dart';

/// Prospect Hub Screen - detailed view of a prospect
class ProspectHubScreen extends ConsumerStatefulWidget {
  final String prospectId;

  const ProspectHubScreen({super.key, required this.prospectId});

  @override
  ConsumerState<ProspectHubScreen> createState() => _ProspectHubScreenState();
}

class _ProspectHubScreenState extends ConsumerState<ProspectHubScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isAddingNote = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hubData = ref.watch(prospectHubProvider(widget.prospectId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      body: hubData.when(
        data: (data) => _buildContent(context, data, isDark),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, e.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProspectHubData data, bool isDark) {
    final notesState = ref.watch(notesProvider(widget.prospectId));

    // Initialize notes from hub data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notesState.notes.isEmpty && data.notes.isNotEmpty) {
        ref.read(notesProvider(widget.prospectId).notifier).setNotes(data.notes);
      }
    });

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: isDark ? AppTheme.slate900 : Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeader(context, data, isDark),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showActionsSheet(context, data),
            ),
          ],
        ),

        // Journey Progress
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _JourneyProgress(data: data),
          ),
        ),

        // Upcoming Meetings
        if (data.upcomingMeetings.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSection(
                context,
                icon: Icons.calendar_today,
                iconColor: AppTheme.primaryBlue,
                title: 'Upcoming Meetings',
                child: Column(
                  children: data.upcomingMeetings
                      .map((m) => _MeetingTile(meeting: m))
                      .toList(),
                ),
              ),
            ),
          ),

        if (data.upcomingMeetings.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Documents
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSection(
              context,
              icon: Icons.folder_outlined,
              iconColor: AppTheme.successGreen,
              title: 'Documents',
              trailing: Text(
                '${data.totalDocuments}',
                style: TextStyle(
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: _DocumentsGrid(data: data),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Contacts
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSection(
              context,
              icon: Icons.people_outline,
              iconColor: AppTheme.accentPurple,
              title: 'Contacts',
              trailing: Text(
                '${data.contacts.length}',
                style: TextStyle(
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: data.contacts.isEmpty
                  ? _EmptyState(
                      icon: Icons.person_add_outlined,
                      message: 'No contacts yet',
                      action: 'Add in web app',
                    )
                  : Column(
                      children: data.contacts
                          .map((c) => _ContactTile(contact: c))
                          .toList(),
                    ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Notes
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSection(
              context,
              icon: Icons.sticky_note_2_outlined,
              iconColor: AppTheme.warningAmber,
              title: 'Notes',
              trailing: IconButton(
                icon: Icon(
                  _isAddingNote ? Icons.close : Icons.add,
                  color: AppTheme.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _isAddingNote = !_isAddingNote;
                    if (!_isAddingNote) _noteController.clear();
                  });
                },
              ),
              child: Column(
                children: [
                  if (_isAddingNote) _buildNoteInput(context),
                  if (notesState.sortedNotes.isEmpty && !_isAddingNote)
                    _EmptyState(
                      icon: Icons.note_add_outlined,
                      message: 'No notes yet',
                      action: 'Tap + to add a note',
                    )
                  else
                    for (final n in notesState.sortedNotes)
                      _NoteTile(
                        note: n,
                        prospectId: widget.prospectId,
                      ),
                ],
              ),
            ),
          ),
        ),

        // Quick Actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _QuickActions(data: data),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ProspectHubData data, bool isDark) {
    final prospect = data.prospect;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.primaryBlueDark, AppTheme.slate900]
              : [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        prospect.initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prospect.companyName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (prospect.industry != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            prospect.industry!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (prospect.website != null || prospect.country != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    if (prospect.website != null)
                      _HeaderChip(
                        icon: Icons.language,
                        label: prospect.displayWebsite!,
                        onTap: () => _launchUrl(prospect.website!),
                      ),
                    if (prospect.country != null)
                      _HeaderChip(
                        icon: Icons.location_on,
                        label: prospect.country!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
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
                if (trailing != null) trailing,
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

  Widget _buildNoteInput(BuildContext context) {
    final notesNotifier = ref.read(notesProvider(widget.prospectId).notifier);
    final notesState = ref.watch(notesProvider(widget.prospectId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write a note...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isAddingNote = false;
                    _noteController.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: notesState.isLoading
                    ? null
                    : () async {
                        if (_noteController.text.trim().isEmpty) return;
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await notesNotifier.addNote(_noteController.text);
                          setState(() {
                            _isAddingNote = false;
                            _noteController.clear();
                          });
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to add note: $e')),
                            );
                          }
                        }
                      },
                child: notesState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load prospect',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.slate500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.refresh(prospectHubProvider(widget.prospectId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context, ProspectHubData data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Record Meeting'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '${AppRoutes.recording}?prospectId=${data.prospect.id}&prospectName=${Uri.encodeComponent(data.prospect.companyName)}',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Research Company'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.researchCreate);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Create Preparation'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.preparationCreate);
                },
              ),
              if (data.prospect.website != null)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Visit Website'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(data.prospect.website!);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Header chip widget
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeaderChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Journey progress indicator
class _JourneyProgress extends StatelessWidget {
  final ProspectHubData data;

  const _JourneyProgress({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = [
      _JourneyStep('Research', Icons.search, data.hasResearch),
      _JourneyStep('Contacts', Icons.people, data.contacts.isNotEmpty),
      _JourneyStep('Prep', Icons.edit_note, data.hasPreparation),
      _JourneyStep('Followup', Icons.analytics, data.hasFollowup),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Sales Journey',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connector line
                final prevComplete = steps[index ~/ 2].isComplete;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: prevComplete
                        ? AppTheme.successGreen
                        : isDark
                            ? AppTheme.slate700
                            : AppTheme.slate300,
                  ),
                );
              }
              final step = steps[index ~/ 2];
              return _buildStep(context, step, isDark);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, _JourneyStep step, bool isDark) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: step.isComplete
                ? AppTheme.successGreen
                : isDark
                    ? AppTheme.slate800
                    : AppTheme.slate100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            step.icon,
            size: 20,
            color: step.isComplete
                ? Colors.white
                : isDark
                    ? AppTheme.slate500
                    : AppTheme.slate400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: step.isComplete ? FontWeight.w600 : FontWeight.normal,
            color: step.isComplete
                ? (isDark ? Colors.white : AppTheme.slate900)
                : AppTheme.slate500,
          ),
        ),
      ],
    );
  }
}

class _JourneyStep {
  final String label;
  final IconData icon;
  final bool isComplete;

  _JourneyStep(this.label, this.icon, this.isComplete);
}

/// Documents grid
class _DocumentsGrid extends StatelessWidget {
  final ProspectHubData data;

  const _DocumentsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.totalDocuments == 0) {
      return _EmptyState(
        icon: Icons.folder_open,
        message: 'No documents yet',
        action: 'Create research or preparation',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (data.research.isNotEmpty)
            _DocumentRow(
              icon: Icons.search,
              color: AppTheme.primaryBlue,
              title: 'Research',
              count: data.research.length,
              onTap: () {
                if (data.research.isNotEmpty) {
                  context.push('/research/${data.research.first.id}');
                }
              },
            ),
          if (data.preparations.isNotEmpty)
            _DocumentRow(
              icon: Icons.edit_note,
              color: AppTheme.successGreen,
              title: 'Preparations',
              count: data.preparations.length,
              onTap: () {
                if (data.preparations.isNotEmpty) {
                  context.push('/preparation/${data.preparations.first.id}');
                }
              },
            ),
          if (data.followups.isNotEmpty)
            _DocumentRow(
              icon: Icons.analytics,
              color: AppTheme.warningAmber,
              title: 'Meeting Analysis',
              count: data.followups.length,
              onTap: () {
                if (data.followups.isNotEmpty) {
                  context.push('/followup/${data.followups.first.id}');
                }
              },
            ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _DocumentRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppTheme.slate900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.slate800 : AppTheme.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppTheme.slate400, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Meeting tile
class _MeetingTile extends StatelessWidget {
  final MeetingSummary meeting;

  const _MeetingTile({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.go(AppRoutes.meetings),
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
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM').format(meeting.startTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                meeting.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppTheme.slate900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: meeting.isPrepared
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : AppTheme.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                meeting.isPrepared ? 'Ready' : 'Prep',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: meeting.isPrepared
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contact tile
class _ContactTile extends StatelessWidget {
  final Contact contact;

  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: contact.email != null ? () => _launchEmail(contact.email!) : null,
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
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.1),
              child: Text(
                contact.initial,
                style: const TextStyle(
                  color: AppTheme.accentPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppTheme.slate900,
                        ),
                      ),
                      if (contact.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (contact.role != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact.role!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (contact.email != null)
              Icon(Icons.mail_outline, color: AppTheme.slate400, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Note tile
class _NoteTile extends ConsumerWidget {
  final ProspectNote note;
  final String prospectId;

  const _NoteTile({required this.note, required this.prospectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.errorRed,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Note'),
            content: const Text('Are you sure you want to delete this note?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(notesProvider(prospectId).notifier).deleteNote(note.id);
      },
      child: InkWell(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          ref.read(notesProvider(prospectId).notifier).togglePin(note.id);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: AppTheme.warningAmber,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      DateFormat('d MMM, HH:mm').format(note.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.slate900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String action;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.slate300),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            action,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick actions at bottom
class _QuickActions extends StatelessWidget {
  final ProspectHubData data;

  const _QuickActions({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.mic,
            label: 'Record',
            color: AppTheme.errorRed,
            onTap: () => context.push(
              '${AppRoutes.recording}?prospectId=${data.prospect.id}&prospectName=${Uri.encodeComponent(data.prospect.companyName)}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.edit_note,
            label: 'Prepare',
            color: AppTheme.successGreen,
            onTap: () => context.push(AppRoutes.preparationCreate),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


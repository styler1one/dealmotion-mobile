import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../research/domain/company_search_result.dart';
import '../../research/providers/research_provider.dart';
import '../../research/presentation/widgets/company_search_widget.dart';
import '../domain/preparation_model.dart';
import '../providers/preparation_provider.dart';

/// Preparation Create Screen - Company search and details flow
class PreparationCreateScreen extends ConsumerStatefulWidget {
  const PreparationCreateScreen({super.key});

  @override
  ConsumerState<PreparationCreateScreen> createState() =>
      _PreparationCreateScreenState();
}

class _PreparationCreateScreenState
    extends ConsumerState<PreparationCreateScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reset state when entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companySearchProvider.notifier).reset();
      ref.read(createPreparationProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onCompanySelected(CompanySearchResult company) {
    HapticFeedback.selectionClick();
    ref.read(createPreparationProvider.notifier).selectCompany(company);
  }

  void _clearSelection() {
    ref.read(createPreparationProvider.notifier).clearCompany();
    ref.read(companySearchProvider.notifier).reset();
  }

  Future<void> _startPreparation() async {
    HapticFeedback.mediumImpact();

    // Update notes from controller
    ref
        .read(createPreparationProvider.notifier)
        .setUserNotes(_notesController.text);

    final preparation =
        await ref.read(createPreparationProvider.notifier).startPreparation();

    if (preparation != null && mounted) {
      context.pushReplacement('/preparation/${preparation.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final createState = ref.watch(createPreparationProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.slate900 : Colors.white,
        title: const Text('New Preparation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (createState.selectedCompany != null) {
              _clearSelection();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: createState.selectedCompany == null
          ? _buildSearchStep()
          : _buildDetailsStep(isDark, createState),
    );
  }

  /// Step 1: Search/Select company
  Widget _buildSearchStep() {
    final unpreparedMeetings = ref.watch(unpreparedMeetingsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Unprepared meetings suggestion
            unpreparedMeetings.when(
              data: (meetings) {
                if (meetings.isEmpty) return const SizedBox.shrink();
                return _UnpreparedMeetingsSection(
                  meetings: meetings,
                  onMeetingSelected: (meeting) {
                    final prospect = meeting['prospects'] as Map<String, dynamic>?;
                    if (prospect != null) {
                      final company = CompanySearchResult(
                        name: prospect['company_name'] as String? ?? '',
                        domain: prospect['website'] as String?,
                        industry: prospect['industry'] as String?,
                        isExistingProspect: true,
                        prospectId: prospect['id'] as String?,
                      );
                      ref.read(createPreparationProvider.notifier)
                          .setCalendarMeetingId(meeting['id'] as String?);
                      _onCompanySelected(company);
                    }
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            CompanySearchWidget(
              title: 'Which company is the meeting with?',
              subtitle: 'Search or select from your prospects',
              onCompanySelected: _onCompanySelected,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Step 2: Fill in details
  Widget _buildDetailsStep(bool isDark, CreatePreparationState createState) {
    final company = createState.selectedCompany!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Card
            _CompanyCard(
              company: company,
              hasResearch: createState.hasResearch,
              isCheckingResearch: createState.isCheckingResearch,
              onEdit: _clearSelection,
            ),

            const SizedBox(height: 20),

            // No research warning
            if (!createState.hasResearch && !createState.isCheckingResearch)
              _NoResearchWarning(
                onResearchFirst: () {
                  context.push('/research/create');
                },
              ),

            if (!createState.hasResearch && !createState.isCheckingResearch)
              const SizedBox(height: 20),

            // Meeting Type
            _MeetingTypeSelector(
              selectedType: createState.meetingType,
              onTypeSelected: (type) {
                ref
                    .read(createPreparationProvider.notifier)
                    .setMeetingType(type);
              },
            ),

            const SizedBox(height: 20),

            // Contacts
            if (createState.availableContacts.isNotEmpty) ...[
              _ContactsSelector(
                contacts: createState.availableContacts,
                selectedIds: createState.selectedContactIds,
                isLoading: createState.isLoadingContacts,
                onToggle: (id) {
                  ref
                      .read(createPreparationProvider.notifier)
                      .toggleContact(id);
                },
              ),
              const SizedBox(height: 20),
            ],

            // Notes
            _NotesInput(
              controller: _notesController,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: createState.isCreating ? null : _startPreparation,
                icon: createState.isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch),
                label: Text(createState.isCreating
                    ? 'Starting...'
                    : 'Start Preparation (uses 1 credit)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Error message
            if (createState.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        createState.error!,
                        style: TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Not the right company?
            Center(
              child: TextButton(
                onPressed: _clearSelection,
                child: Text(
                  'Not the right company? Search again',
                  style: TextStyle(color: AppTheme.slate500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unprepared meetings section
class _UnpreparedMeetingsSection extends StatelessWidget {
  final List<Map<String, dynamic>> meetings;
  final void Function(Map<String, dynamic> meeting) onMeetingSelected;

  const _UnpreparedMeetingsSection({
    required this.meetings,
    required this.onMeetingSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 UPCOMING MEETINGS (not prepared)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...meetings.take(3).map((meeting) {
            final prospect = meeting['prospects'] as Map<String, dynamic>?;
            final companyName = prospect?['company_name'] as String? ?? 'Unknown';
            final startTime = DateTime.tryParse(meeting['start_time'] as String? ?? '');
            final title = meeting['title'] as String? ?? 'Meeting';

            return InkWell(
              onTap: () => onMeetingSelected(meeting),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.slate900 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningAmber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.business,
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
                            companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.slate900,
                            ),
                          ),
                          Text(
                            '$title • ${_formatTime(startTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚠️ Not prepared',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final isToday = time.day == now.day &&
        time.month == now.month &&
        time.year == now.year;
    final isTomorrow = time.day == now.day + 1 &&
        time.month == now.month &&
        time.year == now.year;

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (isToday) return 'Today $timeStr';
    if (isTomorrow) return 'Tomorrow $timeStr';
    return '${time.day}/${time.month} $timeStr';
  }
}

/// Company card
class _CompanyCard extends StatelessWidget {
  final CompanySearchResult company;
  final bool hasResearch;
  final bool isCheckingResearch;
  final VoidCallback onEdit;

  const _CompanyCard({
    required this.company,
    required this.hasResearch,
    required this.isCheckingResearch,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.slate800 : AppTheme.slate200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                company.initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
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
                    Flexible(
                      child: Text(
                        company.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.slate900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCheckingResearch) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ] else if (hasResearch) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                if (company.displayDomain != null ||
                    company.industry != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [company.industry, company.displayDomain]
                        .whereType<String>()
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
                if (hasResearch && !isCheckingResearch) ...[
                  const SizedBox(height: 4),
                  Text(
                    '✅ Research available',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: AppTheme.slate400),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// No research warning
class _NoResearchWarning extends StatelessWidget {
  final VoidCallback onResearchFirst;

  const _NoResearchWarning({required this.onResearchFirst});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.warningAmber, size: 20),
              const SizedBox(width: 8),
              Text(
                'TIP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Research helps create better meeting preparations with more relevant talking points.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.slate300 : AppTheme.slate700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onResearchFirst,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  child: const Text('Research First'),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'or continue below',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Meeting type selector
class _MeetingTypeSelector extends StatelessWidget {
  final MeetingType selectedType;
  final void Function(MeetingType) onTypeSelected;

  const _MeetingTypeSelector({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meeting Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MeetingType.values.map((type) {
            final isSelected = type == selectedType;
            return ChoiceChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (_) => onTypeSelected(type),
              selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : (isDark ? Colors.white : AppTheme.slate700),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryBlue : AppTheme.slate300,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Contacts selector
class _ContactsSelector extends StatelessWidget {
  final List<Contact> contacts;
  final List<String> selectedIds;
  final bool isLoading;
  final void Function(String) onToggle;

  const _ContactsSelector({
    required this.contacts,
    required this.selectedIds,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Contacts (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.slate700,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select contacts to include in the preparation',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.slate500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: contacts.map((contact) {
            final isSelected = selectedIds.contains(contact.id);
            return FilterChip(
              avatar: CircleAvatar(
                backgroundColor: isSelected
                    ? AppTheme.primaryBlue
                    : AppTheme.slate300,
                child: Text(
                  contact.name.isNotEmpty
                      ? contact.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppTheme.slate600,
                  ),
                ),
              ),
              label: Text(contact.name),
              selected: isSelected,
              onSelected: (_) => onToggle(contact.id),
              selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : (isDark ? Colors.white : AppTheme.slate700),
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryBlue : AppTheme.slate300,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Notes input
class _NotesInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _NotesInput({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any specific focus areas or context for the meeting...',
            hintStyle: TextStyle(color: AppTheme.slate400),
            filled: true,
            fillColor: isDark ? AppTheme.slate800 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.slate700 : AppTheme.slate200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.slate700 : AppTheme.slate200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryBlue,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tip: Voice input coming soon 🎤',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.slate400,
          ),
        ),
      ],
    );
  }
}


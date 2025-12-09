import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/company_search_result.dart';
import '../providers/research_provider.dart';
import 'widgets/company_search_widget.dart';

/// Research Create Screen - Company search flow
class ResearchCreateScreen extends ConsumerStatefulWidget {
  const ResearchCreateScreen({super.key});

  @override
  ConsumerState<ResearchCreateScreen> createState() => _ResearchCreateScreenState();
}

class _ResearchCreateScreenState extends ConsumerState<ResearchCreateScreen> {
  CompanySearchResult? _selectedCompany;
  String _outputLanguage = 'en';

  @override
  void initState() {
    super.initState();
    // Reset search state when entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companySearchProvider.notifier).reset();
      ref.read(createResearchProvider.notifier).reset();
    });
  }

  void _onCompanySelected(CompanySearchResult company) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCompany = company;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCompany = null;
    });
    ref.read(companySearchProvider.notifier).reset();
  }

  Future<void> _startResearch() async {
    if (_selectedCompany == null) return;

    HapticFeedback.mediumImpact();

    ref.read(createResearchProvider.notifier).setOutputLanguage(_outputLanguage);
    final research = await ref
        .read(createResearchProvider.notifier)
        .startResearch(_selectedCompany!);

    if (research != null && mounted) {
      // Navigate to processing/detail screen
      context.pushReplacement('/research/${research.id}');
    }
  }

  Future<void> _refreshResearch() async {
    if (_selectedCompany?.researchId == null) return;

    HapticFeedback.mediumImpact();

    final research = await ref
        .read(createResearchProvider.notifier)
        .refreshResearch(_selectedCompany!.researchId!);

    if (research != null && mounted) {
      context.pushReplacement('/research/${research.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final createState = ref.watch(createResearchProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.slate950 : AppTheme.slate50,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.slate900 : Colors.white,
        title: const Text('New Research'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedCompany != null) {
              _clearSelection();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _selectedCompany == null
          ? _buildSearchStep()
          : _buildConfirmStep(isDark, createState),
    );
  }

  /// Step 1: Search for company
  Widget _buildSearchStep() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            CompanySearchWidget(
              title: 'Which company do you want to research?',
              subtitle: 'Search or select from your prospects',
              onCompanySelected: _onCompanySelected,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Step 2: Confirm company
  Widget _buildConfirmStep(bool isDark, CreateResearchState createState) {
    final company = _selectedCompany!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Card
            Container(
              padding: const EdgeInsets.all(20),
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        company.initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
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
                          company.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.slate900,
                          ),
                        ),
                        if (company.industry != null ||
                            company.displayDomain != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [company.industry, company.displayDomain]
                                .whereType<String>()
                                .join(' • '),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                        if (company.location != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppTheme.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                company.location!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: AppTheme.slate400),
                    onPressed: _clearSelection,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Existing research warning
            if (company.hasResearch) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Research already exists',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can view or refresh the existing research',
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
              ),

              const SizedBox(height: 16),

              // View existing research button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/research/${company.researchId}');
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Research'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Refresh button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: createState.isCreating ? null : _refreshResearch,
                  icon: createState.isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(createState.isCreating
                      ? 'Refreshing...'
                      : 'Refresh Research (uses 1 credit)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              // Output language selector
              Text(
                'Output Language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.slate700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.slate700 : AppTheme.slate200,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _outputLanguage,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(12),
                    items: const [
                      DropdownMenuItem(
                        value: 'en',
                        child: Row(
                          children: [
                            Text('🇬🇧'),
                            SizedBox(width: 12),
                            Text('English'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'nl',
                        child: Row(
                          children: [
                            Text('🇳🇱'),
                            SizedBox(width: 12),
                            Text('Dutch'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'de',
                        child: Row(
                          children: [
                            Text('🇩🇪'),
                            SizedBox(width: 12),
                            Text('German'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'fr',
                        child: Row(
                          children: [
                            Text('🇫🇷'),
                            SizedBox(width: 12),
                            Text('French'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _outputLanguage = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Start research button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: createState.isCreating ? null : _startResearch,
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
                      : 'Start Research (uses 1 credit)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],

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
                  style: TextStyle(
                    color: AppTheme.slate500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


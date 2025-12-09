import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/company_search_result.dart';
import '../../providers/research_provider.dart';

/// Reusable company search widget
class CompanySearchWidget extends ConsumerStatefulWidget {
  final void Function(CompanySearchResult company) onCompanySelected;
  final String? title;
  final String? subtitle;

  const CompanySearchWidget({
    super.key,
    required this.onCompanySelected,
    this.title,
    this.subtitle,
  });

  @override
  ConsumerState<CompanySearchWidget> createState() => _CompanySearchWidgetState();
}

class _CompanySearchWidgetState extends ConsumerState<CompanySearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(companySearchProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(companySearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.title!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.slate900,
              ),
            ),
          ),
        
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search companies...',
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.slate400,
              ),
              suffixIcon: state.query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.slate400),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(companySearchProvider.notifier).reset();
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppTheme.slate800 : AppTheme.slate100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),

        const SizedBox(height: 16),

        // Loading indicator
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),

        // Search results
        if (!state.isLoading && state.searchResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'SEARCH RESULTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...state.searchResults.map((company) => _CompanyTile(
                company: company,
                onTap: () => widget.onCompanySelected(company),
              )),
        ],

        // Existing prospects (when not searching)
        if (!state.isLoading &&
            state.query.isEmpty &&
            state.existingProspects.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'YOUR PROSPECTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...state.existingProspects.take(5).map((company) => _CompanyTile(
                company: company,
                onTap: () => widget.onCompanySelected(company),
              )),
        ],

        // Filtered prospects (when searching)
        if (!state.isLoading &&
            state.query.isNotEmpty &&
            state.filteredProspects.isNotEmpty &&
            state.searchResults.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'FROM YOUR PROSPECTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...state.filteredProspects.map((company) => _CompanyTile(
                company: company,
                onTap: () => widget.onCompanySelected(company),
              )),
        ],

        // Empty state
        if (!state.isLoading &&
            state.query.length >= 2 &&
            state.searchResults.isEmpty &&
            state.filteredProspects.isEmpty)
          _EmptySearchState(query: state.query),

        // Manual entry option
        if (!state.isLoading && state.query.length >= 2)
          Padding(
            padding: const EdgeInsets.all(20),
            child: _ManualEntryButton(
              query: state.query,
              onTap: () {
                // Create a manual entry company
                widget.onCompanySelected(CompanySearchResult(
                  name: state.query,
                  isExistingProspect: false,
                ));
              },
            ),
          ),
      ],
    );
  }
}

/// Company tile
class _CompanyTile extends StatelessWidget {
  final CompanySearchResult company;
  final VoidCallback onTap;

  const _CompanyTile({
    required this.company,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: company.isExistingProspect
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : AppTheme.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: company.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          company.logoUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            company.initial,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: company.isExistingProspect
                                  ? AppTheme.primaryBlue
                                  : AppTheme.slate500,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        company.initial,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: company.isExistingProspect
                              ? AppTheme.primaryBlue
                              : AppTheme.slate500,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (company.industry != null) ...[
                        Text(
                          company.industry!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate500,
                          ),
                        ),
                        if (company.displayDomain != null)
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate400,
                            ),
                          ),
                      ],
                      if (company.displayDomain != null)
                        Text(
                          company.displayDomain!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Status badges
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (company.isExistingProspect)
                  _StatusBadge(
                    label: 'Prospect',
                    color: AppTheme.primaryBlue,
                  ),
                if (company.hasResearch)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _StatusBadge(
                      label: 'Research',
                      color: AppTheme.successGreen,
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 8),
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

/// Status badge
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Empty search state
class _EmptySearchState extends StatelessWidget {
  final String query;

  const _EmptySearchState({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AppTheme.slate300,
          ),
          const SizedBox(height: 16),
          Text(
            'No companies found for "$query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : AppTheme.slate700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can enter the company manually',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual entry button
class _ManualEntryButton extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _ManualEntryButton({
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppTheme.slate700 : AppTheme.slate300,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_business,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use "$query"',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppTheme.slate900,
                    ),
                  ),
                  Text(
                    'Enter company details manually',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: AppTheme.slate400,
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/prospect.dart';
import '../../auth/providers/auth_provider.dart';
import '../../recording/providers/local_recordings_provider.dart';
import '../providers/prospect_provider.dart';

/// Prospects list screen - select a prospect before recording
class ProspectsScreen extends ConsumerStatefulWidget {
  const ProspectsScreen({super.key});

  @override
  ConsumerState<ProspectsScreen> createState() => _ProspectsScreenState();
}

class _ProspectsScreenState extends ConsumerState<ProspectsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    ref.read(prospectsProvider.notifier).setSearchQuery(_searchController.text);
  }

  void _selectProspect(Prospect prospect) {
    // Navigate to Prospect Hub for detailed view
    context.push('/prospect/${prospect.id}');
  }

  void _startWithoutProspect() {
    context.push(AppRoutes.recording);
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(ref.read(currentUserProvider)?.email ?? 'Account'),
                subtitle: const Text('Signed in'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Recording History'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.recordings);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.settings);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorRed),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prospectsState = ref.watch(prospectsProvider);
    final pendingCount = ref.watch(pendingRecordingsCountProvider);

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated) {
        context.go(AppRoutes.login);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Prospect'),
        actions: [
          // Pending uploads indicator
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Badge(
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.cloud_upload_outlined),
                ),
                onPressed: () => context.go(AppRoutes.recordings),
                tooltip: '$pendingCount pending uploads',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search prospects...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: prospectsState.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(prospectsProvider.notifier).clearSearch();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Quick action - record without prospect
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Material(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _startWithoutProspect,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Recording',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Start without selecting a prospect',
                              style: TextStyle(
                                color: AppTheme.slate500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppTheme.slate400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Divider with text
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'OR SELECT A PROSPECT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate400,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),

          // Error message
          if (prospectsState.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prospectsState.error!,
                        style: const TextStyle(color: AppTheme.errorRed),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(prospectsProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Prospects list
          Expanded(
            child: prospectsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : prospectsState.filteredProspects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              prospectsState.searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.business_outlined,
                              size: 48,
                              color: AppTheme.slate300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              prospectsState.searchQuery.isNotEmpty
                                  ? 'No prospects found'
                                  : 'No prospects yet',
                              style: TextStyle(
                                color: AppTheme.slate500,
                                fontSize: 16,
                              ),
                            ),
                            if (prospectsState.searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Add prospects in the web app',
                                style: TextStyle(
                                  color: AppTheme.slate400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(prospectsProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: prospectsState.filteredProspects.length,
                          itemBuilder: (context, index) {
                            final prospect = prospectsState.filteredProspects[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.primaryBlue.withOpacity(0.1),
                                  child: Text(
                                    prospect.initial,
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(prospect.companyName),
                                subtitle: Text(
                                  prospect.displayWebsite ?? prospect.industry ?? '',
                                  style: TextStyle(color: AppTheme.slate500),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _selectProspect(prospect),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}

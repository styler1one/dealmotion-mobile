import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/prospect.dart';
import '../data/prospect_repository.dart';

/// Prospect repository provider
final prospectRepositoryProvider = Provider<ProspectRepository>((ref) {
  return ProspectRepository();
});

/// Prospects list state
class ProspectsState {
  final List<Prospect> prospects;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const ProspectsState({
    this.prospects = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  ProspectsState copyWith({
    List<Prospect>? prospects,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return ProspectsState(
      prospects: prospects ?? this.prospects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get filtered prospects based on search query
  List<Prospect> get filteredProspects {
    if (searchQuery.isEmpty) return prospects;
    final query = searchQuery.toLowerCase();
    return prospects.where((p) {
      return p.companyName.toLowerCase().contains(query) ||
          (p.website?.toLowerCase().contains(query) ?? false) ||
          (p.industry?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

/// Prospects notifier
class ProspectsNotifier extends StateNotifier<ProspectsState> {
  final ProspectRepository _repository;

  ProspectsNotifier(this._repository) : super(const ProspectsState()) {
    loadProspects();
  }

  /// Load prospects from API
  Future<void> loadProspects() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final prospects = await _repository.getProspects();
      state = state.copyWith(
        prospects: prospects,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh prospects
  Future<void> refresh() async {
    await loadProspects();
  }

  /// Update search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

/// Prospects provider
final prospectsProvider =
    StateNotifierProvider<ProspectsNotifier, ProspectsState>((ref) {
  final repository = ref.watch(prospectRepositoryProvider);
  return ProspectsNotifier(repository);
});

/// Single prospect provider
final prospectProvider =
    FutureProvider.family<Prospect?, String>((ref, id) async {
  final repository = ref.watch(prospectRepositoryProvider);
  return repository.getProspect(id);
});


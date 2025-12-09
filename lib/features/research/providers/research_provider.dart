import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/research_repository.dart';
import '../domain/company_search_result.dart';
import '../domain/research_model.dart';

// Repository provider
final researchRepositoryProvider = Provider<ResearchRepository>((ref) {
  return ResearchRepository();
});

// Company search state
class CompanySearchState {
  final String query;
  final List<CompanySearchResult> existingProspects;
  final List<CompanySearchResult> searchResults;
  final bool isLoading;
  final String? error;
  final CompanySearchResult? selectedCompany;

  const CompanySearchState({
    this.query = '',
    this.existingProspects = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
    this.selectedCompany,
  });

  CompanySearchState copyWith({
    String? query,
    List<CompanySearchResult>? existingProspects,
    List<CompanySearchResult>? searchResults,
    bool? isLoading,
    String? error,
    CompanySearchResult? selectedCompany,
    bool clearSelected = false,
    bool clearError = false,
  }) {
    return CompanySearchState(
      query: query ?? this.query,
      existingProspects: existingProspects ?? this.existingProspects,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedCompany: clearSelected ? null : (selectedCompany ?? this.selectedCompany),
    );
  }

  /// Get filtered existing prospects based on query
  List<CompanySearchResult> get filteredProspects {
    if (query.isEmpty) return existingProspects;
    final q = query.toLowerCase();
    return existingProspects
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }
}

// Company search notifier
class CompanySearchNotifier extends StateNotifier<CompanySearchState> {
  final ResearchRepository _repository;

  CompanySearchNotifier(this._repository) : super(const CompanySearchState()) {
    _loadProspects();
  }

  Future<void> _loadProspects() async {
    try {
      final prospects = await _repository.getProspects(limit: 20);
      state = state.copyWith(existingProspects: prospects);
    } catch (e) {
      print('Error loading prospects: $e');
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearError: true);

    if (query.length < 2) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final results = await _repository.searchCompanies(query);
      state = state.copyWith(
        searchResults: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectCompany(CompanySearchResult company) {
    state = state.copyWith(selectedCompany: company);
  }

  void clearSelection() {
    state = state.copyWith(clearSelected: true, query: '');
  }

  void reset() {
    state = CompanySearchState(existingProspects: state.existingProspects);
  }
}

// Provider
final companySearchProvider =
    StateNotifierProvider<CompanySearchNotifier, CompanySearchState>((ref) {
  final repository = ref.watch(researchRepositoryProvider);
  return CompanySearchNotifier(repository);
});

// Research list state
class ResearchListState {
  final List<Research> items;
  final bool isLoading;
  final String? error;

  const ResearchListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ResearchListState copyWith({
    List<Research>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ResearchListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Research list notifier
class ResearchListNotifier extends StateNotifier<ResearchListState> {
  final ResearchRepository _repository;

  ResearchListNotifier(this._repository) : super(const ResearchListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _repository.getResearchList();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

// Provider
final researchListProvider =
    StateNotifierProvider<ResearchListNotifier, ResearchListState>((ref) {
  final repository = ref.watch(researchRepositoryProvider);
  return ResearchListNotifier(repository);
});

// Create research state
class CreateResearchState {
  final bool isCreating;
  final Research? createdResearch;
  final String? error;
  final String outputLanguage;

  const CreateResearchState({
    this.isCreating = false,
    this.createdResearch,
    this.error,
    this.outputLanguage = 'en',
  });

  CreateResearchState copyWith({
    bool? isCreating,
    Research? createdResearch,
    String? error,
    String? outputLanguage,
    bool clearCreated = false,
    bool clearError = false,
  }) {
    return CreateResearchState(
      isCreating: isCreating ?? this.isCreating,
      createdResearch: clearCreated ? null : (createdResearch ?? this.createdResearch),
      error: clearError ? null : (error ?? this.error),
      outputLanguage: outputLanguage ?? this.outputLanguage,
    );
  }
}

// Create research notifier
class CreateResearchNotifier extends StateNotifier<CreateResearchState> {
  final ResearchRepository _repository;

  CreateResearchNotifier(this._repository) : super(const CreateResearchState());

  void setOutputLanguage(String language) {
    state = state.copyWith(outputLanguage: language);
  }

  Future<Research?> startResearch(CompanySearchResult company) async {
    state = state.copyWith(isCreating: true, clearError: true, clearCreated: true);

    try {
      final research = await _repository.startResearch(
        companyName: company.name,
        website: company.domain,
        linkedinUrl: company.linkedinUrl,
        prospectId: company.prospectId,
        outputLanguage: state.outputLanguage,
      );

      state = state.copyWith(
        isCreating: false,
        createdResearch: research,
      );

      return research;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<Research?> refreshResearch(String researchId) async {
    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final research = await _repository.refreshResearch(researchId);
      state = state.copyWith(
        isCreating: false,
        createdResearch: research,
      );
      return research;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CreateResearchState();
  }
}

// Provider
final createResearchProvider =
    StateNotifierProvider<CreateResearchNotifier, CreateResearchState>((ref) {
  final repository = ref.watch(researchRepositoryProvider);
  return CreateResearchNotifier(repository);
});

// Single research detail provider
final researchDetailProvider =
    FutureProvider.family<Research?, String>((ref, id) async {
  final repository = ref.watch(researchRepositoryProvider);
  return repository.getResearch(id);
});


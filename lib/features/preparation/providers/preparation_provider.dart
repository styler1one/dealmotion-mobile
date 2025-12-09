import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../research/domain/company_search_result.dart';
import '../data/preparation_repository.dart';
import '../domain/preparation_model.dart';

// Repository provider
final preparationRepositoryProvider = Provider<PreparationRepository>((ref) {
  return PreparationRepository();
});

// Preparation list state
class PreparationListState {
  final List<Preparation> items;
  final bool isLoading;
  final String? error;

  const PreparationListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  PreparationListState copyWith({
    List<Preparation>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PreparationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Preparation list notifier
class PreparationListNotifier extends StateNotifier<PreparationListState> {
  final PreparationRepository _repository;

  PreparationListNotifier(this._repository) : super(const PreparationListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _repository.getPreparationList();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

// Provider
final preparationListProvider =
    StateNotifierProvider<PreparationListNotifier, PreparationListState>((ref) {
  final repository = ref.watch(preparationRepositoryProvider);
  return PreparationListNotifier(repository);
});

// Create preparation state
class CreatePreparationState {
  final CompanySearchResult? selectedCompany;
  final MeetingType meetingType;
  final List<Contact> availableContacts;
  final List<String> selectedContactIds;
  final String userNotes;
  final String outputLanguage;
  final String? calendarMeetingId;
  final bool hasResearch;
  final bool isCheckingResearch;
  final bool isLoadingContacts;
  final bool isCreating;
  final Preparation? createdPreparation;
  final String? error;

  const CreatePreparationState({
    this.selectedCompany,
    this.meetingType = MeetingType.discovery,
    this.availableContacts = const [],
    this.selectedContactIds = const [],
    this.userNotes = '',
    this.outputLanguage = 'en',
    this.calendarMeetingId,
    this.hasResearch = false,
    this.isCheckingResearch = false,
    this.isLoadingContacts = false,
    this.isCreating = false,
    this.createdPreparation,
    this.error,
  });

  CreatePreparationState copyWith({
    CompanySearchResult? selectedCompany,
    MeetingType? meetingType,
    List<Contact>? availableContacts,
    List<String>? selectedContactIds,
    String? userNotes,
    String? outputLanguage,
    String? calendarMeetingId,
    bool? hasResearch,
    bool? isCheckingResearch,
    bool? isLoadingContacts,
    bool? isCreating,
    Preparation? createdPreparation,
    String? error,
    bool clearCompany = false,
    bool clearCreated = false,
    bool clearError = false,
    bool clearMeetingId = false,
  }) {
    return CreatePreparationState(
      selectedCompany: clearCompany ? null : (selectedCompany ?? this.selectedCompany),
      meetingType: meetingType ?? this.meetingType,
      availableContacts: availableContacts ?? this.availableContacts,
      selectedContactIds: selectedContactIds ?? this.selectedContactIds,
      userNotes: userNotes ?? this.userNotes,
      outputLanguage: outputLanguage ?? this.outputLanguage,
      calendarMeetingId: clearMeetingId ? null : (calendarMeetingId ?? this.calendarMeetingId),
      hasResearch: hasResearch ?? this.hasResearch,
      isCheckingResearch: isCheckingResearch ?? this.isCheckingResearch,
      isLoadingContacts: isLoadingContacts ?? this.isLoadingContacts,
      isCreating: isCreating ?? this.isCreating,
      createdPreparation: clearCreated ? null : (createdPreparation ?? this.createdPreparation),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Create preparation notifier
class CreatePreparationNotifier extends StateNotifier<CreatePreparationState> {
  final PreparationRepository _repository;

  CreatePreparationNotifier(this._repository) : super(const CreatePreparationState());

  Future<void> selectCompany(CompanySearchResult company) async {
    state = state.copyWith(
      selectedCompany: company,
      isCheckingResearch: true,
      isLoadingContacts: true,
      clearError: true,
    );

    // Check if research exists
    if (company.prospectId != null) {
      try {
        final hasResearch = await _repository.hasResearch(company.prospectId!);
        state = state.copyWith(hasResearch: hasResearch);
      } catch (e) {
        // Ignore errors, just assume no research
      }
    }
    state = state.copyWith(isCheckingResearch: false);

    // Load contacts
    if (company.prospectId != null) {
      try {
        final contacts = await _repository.getProspectContacts(company.prospectId!);
        state = state.copyWith(availableContacts: contacts);
      } catch (e) {
        // Ignore errors
      }
    }
    state = state.copyWith(isLoadingContacts: false);
  }

  void clearCompany() {
    state = state.copyWith(
      clearCompany: true,
      hasResearch: false,
      availableContacts: [],
      selectedContactIds: [],
    );
  }

  void setMeetingType(MeetingType type) {
    state = state.copyWith(meetingType: type);
  }

  void toggleContact(String contactId) {
    final current = List<String>.from(state.selectedContactIds);
    if (current.contains(contactId)) {
      current.remove(contactId);
    } else {
      current.add(contactId);
    }
    state = state.copyWith(selectedContactIds: current);
  }

  void setUserNotes(String notes) {
    state = state.copyWith(userNotes: notes);
  }

  void setOutputLanguage(String language) {
    state = state.copyWith(outputLanguage: language);
  }

  void setCalendarMeetingId(String? meetingId) {
    if (meetingId == null) {
      state = state.copyWith(clearMeetingId: true);
    } else {
      state = state.copyWith(calendarMeetingId: meetingId);
    }
  }

  Future<Preparation?> startPreparation() async {
    if (state.selectedCompany == null) return null;

    state = state.copyWith(isCreating: true, clearError: true, clearCreated: true);

    try {
      // If no prospect ID, we need to create one first (handled by repository)
      final company = state.selectedCompany!;
      
      final preparation = await _repository.startPreparation(
        prospectId: company.prospectId ?? '',
        companyName: company.name,
        website: company.domain,
        meetingType: state.meetingType,
        contactIds: state.selectedContactIds.isNotEmpty ? state.selectedContactIds : null,
        userNotes: state.userNotes.isNotEmpty ? state.userNotes : null,
        calendarMeetingId: state.calendarMeetingId,
        outputLanguage: state.outputLanguage,
      );

      state = state.copyWith(
        isCreating: false,
        createdPreparation: preparation,
      );

      return preparation;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CreatePreparationState();
  }
}

// Provider
final createPreparationProvider =
    StateNotifierProvider<CreatePreparationNotifier, CreatePreparationState>((ref) {
  final repository = ref.watch(preparationRepositoryProvider);
  return CreatePreparationNotifier(repository);
});

// Unprepared meetings provider
final unpreparedMeetingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(preparationRepositoryProvider);
  return repository.getUnpreparedMeetings();
});

// Single preparation detail provider
final preparationDetailProvider =
    FutureProvider.family<Preparation?, String>((ref, id) async {
  final repository = ref.watch(preparationRepositoryProvider);
  return repository.getPreparation(id);
});


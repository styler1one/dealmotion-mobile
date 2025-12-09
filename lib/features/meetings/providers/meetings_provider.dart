import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meetings_repository.dart';
import '../domain/meeting_model.dart';

// Repository provider
final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return MeetingsRepository();
});

/// Tab type for meetings screen
enum MeetingsTab { today, tomorrow, week }

/// Meetings state
class MeetingsState {
  final List<Meeting> todayMeetings;
  final List<Meeting> tomorrowMeetings;
  final List<Meeting> weekMeetings;
  final bool isLoading;
  final bool isSyncing;
  final String? error;
  final MeetingsTab selectedTab;

  const MeetingsState({
    this.todayMeetings = const [],
    this.tomorrowMeetings = const [],
    this.weekMeetings = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
    this.selectedTab = MeetingsTab.today,
  });

  MeetingsState copyWith({
    List<Meeting>? todayMeetings,
    List<Meeting>? tomorrowMeetings,
    List<Meeting>? weekMeetings,
    bool? isLoading,
    bool? isSyncing,
    String? error,
    MeetingsTab? selectedTab,
    bool clearError = false,
  }) {
    return MeetingsState(
      todayMeetings: todayMeetings ?? this.todayMeetings,
      tomorrowMeetings: tomorrowMeetings ?? this.tomorrowMeetings,
      weekMeetings: weekMeetings ?? this.weekMeetings,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }

  /// Get meetings for current tab
  List<Meeting> get currentMeetings {
    switch (selectedTab) {
      case MeetingsTab.today:
        return todayMeetings;
      case MeetingsTab.tomorrow:
        return tomorrowMeetings;
      case MeetingsTab.week:
        return weekMeetings;
    }
  }

  /// Count of unprepared meetings this week
  int get unpreparedCount =>
      weekMeetings.where((m) => !m.isPrepared && !m.isPast).length;

  /// Count of today's meetings
  int get todayCount => todayMeetings.length;
}

/// Meetings notifier
class MeetingsNotifier extends StateNotifier<MeetingsState> {
  final MeetingsRepository _repository;

  MeetingsNotifier(this._repository) : super(const MeetingsState()) {
    loadAll();
  }

  /// Load all meetings
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _repository.getTodayMeetings(),
        _repository.getTomorrowMeetings(),
        _repository.getWeekMeetings(),
      ]);

      state = state.copyWith(
        todayMeetings: results[0],
        tomorrowMeetings: results[1],
        weekMeetings: results[2],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh meetings
  Future<void> refresh() => loadAll();

  /// Sync with calendar provider
  Future<void> syncCalendar() async {
    state = state.copyWith(isSyncing: true);

    try {
      await _repository.syncCalendar();
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Sync failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Change selected tab
  void selectTab(MeetingsTab tab) {
    state = state.copyWith(selectedTab: tab);
  }
}

// Provider
final meetingsProvider =
    StateNotifierProvider<MeetingsNotifier, MeetingsState>((ref) {
  final repository = ref.watch(meetingsRepositoryProvider);
  return MeetingsNotifier(repository);
});

// Today's meetings count provider (for home screen)
final todayMeetingsCountProvider = Provider<int>((ref) {
  final state = ref.watch(meetingsProvider);
  return state.todayCount;
});

// Unprepared meetings count provider
final unpreparedMeetingsCountProvider = Provider<int>((ref) {
  final state = ref.watch(meetingsProvider);
  return state.unpreparedCount;
});


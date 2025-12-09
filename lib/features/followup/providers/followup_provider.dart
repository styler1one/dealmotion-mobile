import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/followup_repository.dart';
import '../domain/followup_model.dart';

// Repository provider
final followupRepositoryProvider = Provider<FollowupRepository>((ref) {
  return FollowupRepository();
});

// Followup list state
class FollowupListState {
  final List<Followup> items;
  final bool isLoading;
  final String? error;

  const FollowupListState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  FollowupListState copyWith({
    List<Followup>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FollowupListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Followup list notifier
class FollowupListNotifier extends StateNotifier<FollowupListState> {
  final FollowupRepository _repository;

  FollowupListNotifier(this._repository) : super(const FollowupListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _repository.getFollowupList();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

// Provider
final followupListProvider =
    StateNotifierProvider<FollowupListNotifier, FollowupListState>((ref) {
  final repository = ref.watch(followupRepositoryProvider);
  return FollowupListNotifier(repository);
});

// Single followup detail provider
final followupDetailProvider =
    FutureProvider.family<Followup?, String>((ref, id) async {
  final repository = ref.watch(followupRepositoryProvider);
  return repository.getFollowup(id);
});

// Recent followups provider (for home screen)
final recentFollowupsProvider = FutureProvider<List<Followup>>((ref) async {
  final repository = ref.watch(followupRepositoryProvider);
  return repository.getRecentFollowups(limit: 3);
});

// Pending followups count provider
final pendingFollowupsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(followupRepositoryProvider);
  return repository.getPendingCount();
});


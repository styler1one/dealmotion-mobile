import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prospect_hub_repository.dart';
import '../domain/prospect_hub_data.dart';

/// Repository provider
final prospectHubRepositoryProvider = Provider<ProspectHubRepository>((ref) {
  return ProspectHubRepository();
});

/// Prospect hub data provider (by ID)
final prospectHubProvider = FutureProvider.family<ProspectHubData, String>((ref, prospectId) async {
  final repository = ref.watch(prospectHubRepositoryProvider);
  return repository.getProspectHub(prospectId);
});

/// State for notes management
class NotesState {
  final List<ProspectNote> notes;
  final bool isLoading;
  final String? error;

  const NotesState({
    this.notes = const [],
    this.isLoading = false,
    this.error,
  });

  NotesState copyWith({
    List<ProspectNote>? notes,
    bool? isLoading,
    String? error,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<ProspectNote> get sortedNotes {
    final sorted = List<ProspectNote>.from(notes);
    sorted.sort((a, b) {
      // Pinned first, then by date
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}

/// Notes notifier for a prospect
class NotesNotifier extends StateNotifier<NotesState> {
  final ProspectHubRepository _repository;
  final String _prospectId;

  NotesNotifier(this._repository, this._prospectId) : super(const NotesState());

  void setNotes(List<ProspectNote> notes) {
    state = state.copyWith(notes: notes);
  }

  Future<void> addNote(String content) async {
    if (content.trim().isEmpty) return;
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final note = await _repository.addNote(_prospectId, content.trim());
      state = state.copyWith(
        notes: [note, ...state.notes],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> togglePin(String noteId) async {
    final noteIndex = state.notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = state.notes[noteIndex];
    try {
      final updated = await _repository.updateNote(
        _prospectId,
        noteId,
        isPinned: !note.isPinned,
      );
      final newNotes = List<ProspectNote>.from(state.notes);
      newNotes[noteIndex] = updated;
      state = state.copyWith(notes: newNotes);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _repository.deleteNote(_prospectId, noteId);
      state = state.copyWith(
        notes: state.notes.where((n) => n.id != noteId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Notes provider family (by prospect ID)
final notesProvider = StateNotifierProvider.family<NotesNotifier, NotesState, String>((ref, prospectId) {
  final repository = ref.watch(prospectHubRepositoryProvider);
  return NotesNotifier(repository, prospectId);
});


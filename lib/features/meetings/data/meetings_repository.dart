import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meeting_model.dart';

/// Repository for meetings operations
class MeetingsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get meetings for a date range
  Future<List<Meeting>> getMeetings({
    required DateTime from,
    required DateTime to,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('calendar_meetings')
        .select('*, prospects(company_name)')
        .gte('start_time', from.toIso8601String())
        .lte('start_time', to.toIso8601String())
        .order('start_time', ascending: true);

    return (response as List<dynamic>)
        .map((json) => Meeting.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get today's meetings
  Future<List<Meeting>> getTodayMeetings() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getMeetings(from: startOfDay, to: endOfDay);
  }

  /// Get tomorrow's meetings
  Future<List<Meeting>> getTomorrowMeetings() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getMeetings(from: startOfDay, to: endOfDay);
  }

  /// Get this week's meetings
  Future<List<Meeting>> getWeekMeetings() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    return getMeetings(from: startOfToday, to: endOfWeek);
  }

  /// Get single meeting by ID
  Future<Meeting?> getMeeting(String id) async {
    final response = await _supabase
        .from('calendar_meetings')
        .select('*, prospects(company_name)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Meeting.fromJson(response);
  }

  /// Get upcoming meetings count
  Future<int> getUpcomingCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final now = DateTime.now();
    final response = await _supabase
        .from('calendar_meetings')
        .select('id')
        .gte('start_time', now.toIso8601String())
        .lte('start_time', now.add(const Duration(days: 7)).toIso8601String());

    return (response as List).length;
  }

  /// Get unprepared meetings count
  Future<int> getUnpreparedCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final now = DateTime.now();
    final response = await _supabase
        .from('calendar_meetings')
        .select('id')
        .isFilter('preparation_id', null)
        .gte('start_time', now.toIso8601String())
        .lte('start_time', now.add(const Duration(days: 7)).toIso8601String());

    return (response as List).length;
  }

  /// Sync calendar (trigger refresh)
  Future<void> syncCalendar() async {
    try {
      await _supabase.functions.invoke('sync-calendar');
    } catch (e) {
      print('Calendar sync failed: $e');
    }
  }
}


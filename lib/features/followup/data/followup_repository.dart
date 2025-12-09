import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/followup_model.dart';

/// Repository for followup operations
class FollowupRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all followups for the user
  Future<List<Followup>> getFollowupList() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('followups')
        .select('*, prospects(company_name)')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Followup.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get single followup by ID
  Future<Followup?> getFollowup(String id) async {
    final response = await _supabase
        .from('followups')
        .select('*, prospects(company_name)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Followup.fromJson(response);
  }

  /// Get recent followups (for home screen)
  Future<List<Followup>> getRecentFollowups({int limit = 5}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('followups')
        .select('*, prospects(company_name)')
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => Followup.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get pending followups count
  Future<int> getPendingCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _supabase
        .from('followups')
        .select('id')
        .inFilter('status', ['pending', 'processing', 'transcribing', 'summarizing']);

    return (response as List).length;
  }
}


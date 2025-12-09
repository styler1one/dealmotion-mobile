import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/api_service.dart';
import '../domain/preparation_model.dart';

/// Repository for preparation operations
class PreparationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiService _api = ApiService.instance;

  /// Get contacts for a prospect
  Future<List<Contact>> getProspectContacts(String prospectId) async {
    final response = await _supabase
        .from('prospect_contacts')
        .select('id, name, role, email, linkedin_url')
        .eq('prospect_id', prospectId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Contact.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Check if research exists for a prospect
  Future<bool> hasResearch(String prospectId) async {
    final response = await _supabase
        .from('research_briefs')
        .select('id')
        .eq('prospect_id', prospectId)
        .eq('status', 'completed')
        .limit(1);

    return (response as List).isNotEmpty;
  }

  /// Start preparation for a meeting - uses backend API
  Future<Preparation> startPreparation({
    required String prospectId,
    required String companyName,
    required MeetingType meetingType,
    String? website, // Not used by API
    List<String>? contactIds,
    String? userNotes,
    String? calendarMeetingId,
    String outputLanguage = 'en',
  }) async {
    // Use the backend API endpoint - this handles:
    // - Finding/validating the prospect
    // - Creating the meeting_prep record
    // - Triggering the Inngest event
    // - Usage tracking
    // - Linking to calendar meeting
    final response = await _api.post(
      '/api/v1/preparation/start',
      data: {
        'prospect_company_name': companyName,
        'meeting_type': meetingType.apiValue,
        'custom_notes': userNotes,
        'contact_ids': contactIds,
        'calendar_meeting_id': calendarMeetingId,
        'language': outputLanguage,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
      throw Exception(response.data?['detail'] ?? 'Failed to start preparation');
    }

    // The API returns the preparation
    return Preparation.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get all preparations for the user
  Future<List<Preparation>> getPreparationList() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('meeting_preps')
        .select('*, prospects(company_name, website)')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Preparation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get single preparation by ID
  Future<Preparation?> getPreparation(String id) async {
    final response = await _supabase
        .from('meeting_preps')
        .select('*, prospects(company_name, website)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Preparation.fromJson(response);
  }

  /// Get upcoming meetings without preparation
  Future<List<Map<String, dynamic>>> getUnpreparedMeetings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final now = DateTime.now();
    final weekLater = now.add(const Duration(days: 7));

    // Get calendar meetings without preparation
    final response = await _supabase
        .from('calendar_meetings')
        .select('''
          id,
          title,
          start_time,
          end_time,
          prospect_id,
          preparation_id,
          prospects(id, company_name, website, industry)
        ''')
        .gte('start_time', now.toIso8601String())
        .lte('start_time', weekLater.toIso8601String())
        .isFilter('preparation_id', null)
        .order('start_time', ascending: true)
        .limit(10);

    return (response as List<dynamic>)
        .map((json) => json as Map<String, dynamic>)
        .toList();
  }

  /// Get recent prospects for quick selection
  Future<List<Map<String, dynamic>>> getRecentProspects({int limit = 5}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('prospects')
        .select('id, company_name, website, industry')
        .order('updated_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => json as Map<String, dynamic>)
        .toList();
  }
}

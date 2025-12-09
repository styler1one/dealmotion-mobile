import '../../../core/services/api_service.dart';
import '../../../core/services/api_endpoints.dart';
import '../../../shared/models/prospect.dart';
import '../domain/prospect_hub_data.dart';

/// Repository for prospect hub data
class ProspectHubRepository {
  final ApiService _api = ApiService.instance;

  /// Get full prospect hub data
  Future<ProspectHubData> getProspectHub(String prospectId) async {
    // Fetch all data in parallel
    final results = await Future.wait([
      _getProspect(prospectId),
      _getContacts(prospectId),
      _getNotes(prospectId),
      _getResearch(prospectId),
      _getPreparations(prospectId),
      _getFollowups(prospectId),
      _getUpcomingMeetings(prospectId),
    ]);

    final prospect = results[0] as Prospect;
    final contacts = results[1] as List<Contact>;
    final notes = results[2] as List<ProspectNote>;
    final research = results[3] as List<DocumentSummary>;
    final preparations = results[4] as List<DocumentSummary>;
    final followups = results[5] as List<DocumentSummary>;
    final meetings = results[6] as List<MeetingSummary>;

    return ProspectHubData(
      prospect: prospect,
      contacts: contacts,
      notes: notes,
      research: research,
      preparations: preparations,
      followups: followups,
      upcomingMeetings: meetings,
    );
  }

  Future<Prospect> _getProspect(String id) async {
    final response = await _api.get(ApiEndpoints.prospect(id));
    return Prospect.fromJson(response.data);
  }

  Future<List<Contact>> _getContacts(String prospectId) async {
    try {
      final response = await _api.get('${ApiEndpoints.prospect(prospectId)}/contacts');
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['contacts'] ?? [];
        return data.map((json) => Contact.fromJson(json)).toList();
      }
    } catch (e) {
      // Contacts endpoint may not exist, return empty
    }
    return [];
  }

  Future<List<ProspectNote>> _getNotes(String prospectId) async {
    try {
      final response = await _api.get('${ApiEndpoints.prospect(prospectId)}/notes');
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['notes'] ?? [];
        return data.map((json) => ProspectNote.fromJson(json)).toList();
      }
    } catch (e) {
      // Notes endpoint may not exist, return empty
    }
    return [];
  }

  Future<List<DocumentSummary>> _getResearch(String prospectId) async {
    try {
      // Use correct endpoint: /api/v1/research/briefs
      final response = await _api.get(
        ApiEndpoints.researchBriefs,
        queryParameters: {'prospect_id': prospectId, 'limit': 5},
      );
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['briefs'] ?? response.data['research'] ?? response.data['data'] ?? [];
        return data.map((json) => DocumentSummary.fromJson(json, 'research')).toList();
      }
    } catch (e) {
      // Research endpoint may fail, return empty
    }
    return [];
  }

  Future<List<DocumentSummary>> _getPreparations(String prospectId) async {
    try {
      // Use correct endpoint: /api/v1/preparation/briefs
      final response = await _api.get(
        ApiEndpoints.preparationBriefs,
        queryParameters: {'prospect_id': prospectId, 'limit': 5},
      );
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['briefs'] ?? response.data['preparations'] ?? response.data['data'] ?? [];
        return data.map((json) => DocumentSummary.fromJson(json, 'preparation')).toList();
      }
    } catch (e) {
      // Preparations endpoint may fail, return empty
    }
    return [];
  }

  Future<List<DocumentSummary>> _getFollowups(String prospectId) async {
    try {
      // Use correct endpoint: /api/v1/followup/list
      final response = await _api.get(
        ApiEndpoints.followupList,
        queryParameters: {'prospect_id': prospectId, 'limit': 5},
      );
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['followups'] ?? response.data['data'] ?? [];
        return data.map((json) => DocumentSummary.fromJson(json, 'followup')).toList();
      }
    } catch (e) {
      // Followups endpoint may fail, return empty
    }
    return [];
  }

  Future<List<MeetingSummary>> _getUpcomingMeetings(String prospectId) async {
    try {
      final response = await _api.get(
        '/api/v1/calendar-meetings',
        queryParameters: {
          'prospect_id': prospectId,
          'filter': 'upcoming',
          'limit': 5,
        },
      );
      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['meetings'] ?? response.data['data'] ?? [];
        return data.map((json) => MeetingSummary.fromJson(json)).toList();
      }
    } catch (e) {
      // Meetings endpoint may fail, return empty
    }
    return [];
  }

  /// Add a note to a prospect
  Future<ProspectNote> addNote(String prospectId, String content) async {
    final response = await _api.post(
      '${ApiEndpoints.prospect(prospectId)}/notes',
      data: {'content': content},
    );
    return ProspectNote.fromJson(response.data);
  }

  /// Update a note
  Future<ProspectNote> updateNote(String prospectId, String noteId, {String? content, bool? isPinned}) async {
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (isPinned != null) body['is_pinned'] = isPinned;
    
    final response = await _api.put(
      '${ApiEndpoints.prospect(prospectId)}/notes/$noteId',
      data: body,
    );
    return ProspectNote.fromJson(response.data);
  }

  /// Delete a note
  Future<void> deleteNote(String prospectId, String noteId) async {
    await _api.delete('${ApiEndpoints.prospect(prospectId)}/notes/$noteId');
  }
}


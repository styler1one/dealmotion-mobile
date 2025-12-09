import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/api_service.dart';
import '../domain/company_search_result.dart';
import '../domain/research_model.dart';

/// Repository for research operations
class ResearchRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiService _api = ApiService.instance;

  /// Search for companies - first checks existing prospects, then external search
  Future<List<CompanySearchResult>> searchCompanies(String query) async {
    if (query.isEmpty || query.length < 2) {
      return [];
    }

    final results = <CompanySearchResult>[];
    final userId = _supabase.auth.currentUser?.id;
    
    if (userId == null) return results;

    // Step 1: Search existing prospects via RLS (no user_id filter needed)
    final prospectResponse = await _supabase
        .from('prospects')
        .select('id, company_name, website, industry, country, linkedin_url, description')
        .ilike('company_name', '%$query%')
        .limit(5);

    // Get research status for each prospect
    for (final prospect in prospectResponse as List<dynamic>) {
      final prospectId = prospect['id'] as String;
      
      // Check if research exists
      final researchResponse = await _supabase
          .from('research_briefs')
          .select('id')
          .eq('prospect_id', prospectId)
          .limit(1);

      final hasResearch = (researchResponse as List).isNotEmpty;
      final researchId = hasResearch ? researchResponse[0]['id'] as String? : null;

      results.add(CompanySearchResult.fromProspect(
        prospect as Map<String, dynamic>,
        hasResearch: hasResearch,
        researchId: researchId,
      ));
    }

    // Step 2: External company search via backend API
    try {
      final response = await _api.post(
        '/api/v1/research/search-company',
        data: {'query': query},
      );

      if (response.data != null && response.data['results'] != null) {
        final externalResults = response.data['results'] as List<dynamic>;
        for (final company in externalResults) {
          // Don't add if already in prospects
          final isDuplicate = results.any((r) =>
              r.name.toLowerCase() == (company['name'] as String? ?? '').toLowerCase() ||
              r.domain == company['domain']);
          
          if (!isDuplicate) {
            results.add(CompanySearchResult.fromJson(company as Map<String, dynamic>));
          }
        }
      }
    } catch (e) {
      // External search is optional, continue with prospect results
      // ignore: avoid_print
      print('External company search failed: $e');
    }

    return results;
  }

  /// Get user's existing prospects (via RLS, no user_id filter needed)
  Future<List<CompanySearchResult>> getProspects({int limit = 10}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('prospects')
        .select('id, company_name, website, industry, country, linkedin_url')
        .order('updated_at', ascending: false)
        .limit(limit);

    final prospects = <CompanySearchResult>[];
    for (final p in response as List<dynamic>) {
      final prospectId = p['id'] as String;
      
      // Check if research exists
      final researchResponse = await _supabase
          .from('research_briefs')
          .select('id')
          .eq('prospect_id', prospectId)
          .limit(1);

      final hasResearch = (researchResponse as List).isNotEmpty;
      final researchId = hasResearch ? researchResponse[0]['id'] as String? : null;

      prospects.add(CompanySearchResult.fromProspect(
        p as Map<String, dynamic>,
        hasResearch: hasResearch,
        researchId: researchId,
      ));
    }

    return prospects;
  }

  /// Start research for a company - uses backend API
  Future<Research> startResearch({
    required String companyName,
    String? website,
    String? linkedinUrl,
    String? prospectId, // Not used by API, but kept for interface compatibility
    String? country,
    String? city,
    String outputLanguage = 'en', // Not used - backend reads from user_settings
  }) async {
    // Use the backend API endpoint - this handles:
    // - Creating/finding the prospect
    // - Creating the research brief
    // - Triggering the Inngest event
    // - Usage tracking
    final response = await _api.post(
      '/api/v1/research/start',
      data: {
        'company_name': companyName,
        'company_website_url': website,
        'company_linkedin_url': linkedinUrl,
        'country': country,
        'city': city,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202) {
      throw Exception(response.data?['detail'] ?? 'Failed to start research');
    }

    // The API returns the research brief
    return Research.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get all research for the user
  Future<List<Research>> getResearchList() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('research_briefs')
        .select('*, prospects(company_name, website)')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Research.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get single research by ID
  Future<Research?> getResearch(String id) async {
    final response = await _supabase
        .from('research_briefs')
        .select('*, prospects(company_name, website)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Research.fromJson(response);
  }

  /// Refresh research (regenerate) - uses backend API
  Future<Research> refreshResearch(String researchId) async {
    final response = await _api.post(
      '/api/v1/research/$researchId/refresh',
    );

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception(response.data?['detail'] ?? 'Failed to refresh research');
    }

    final research = await getResearch(researchId);
    if (research == null) throw Exception('Research not found');
    return research;
  }
}

import '../../../core/services/api_service.dart';
import '../../../core/services/api_endpoints.dart';
import '../../../shared/models/prospect.dart';

/// Repository for prospect data operations
class ProspectRepository {
  final ApiService _api = ApiService.instance;

  /// Fetch all prospects for the current organization
  Future<List<Prospect>> getProspects({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _api.get(
        ApiEndpoints.prospects,
        queryParameters: queryParams,
      );

      if (response.data != null) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : response.data['prospects'] ?? response.data['data'] ?? [];
        return data.map((json) => Prospect.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single prospect by ID
  Future<Prospect?> getProspect(String id) async {
    try {
      final response = await _api.get(ApiEndpoints.prospect(id));
      
      if (response.data != null) {
        return Prospect.fromJson(response.data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Search prospects by company name
  Future<List<Prospect>> searchProspects(String query) async {
    return getProspects(search: query);
  }
}


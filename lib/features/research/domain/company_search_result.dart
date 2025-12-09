/// Company search result model
class CompanySearchResult {
  final String name;
  final String? domain;
  final String? industry;
  final String? location;
  final String? logoUrl;
  final String? linkedinUrl;
  final String? description;
  
  /// True if this is from existing prospects
  final bool isExistingProspect;
  
  /// Prospect ID if it's an existing prospect
  final String? prospectId;
  
  /// True if research already exists for this prospect
  final bool hasResearch;
  
  /// Research ID if research exists
  final String? researchId;

  const CompanySearchResult({
    required this.name,
    this.domain,
    this.industry,
    this.location,
    this.logoUrl,
    this.linkedinUrl,
    this.description,
    this.isExistingProspect = false,
    this.prospectId,
    this.hasResearch = false,
    this.researchId,
  });

  factory CompanySearchResult.fromJson(Map<String, dynamic> json) {
    return CompanySearchResult(
      name: json['name'] as String? ?? json['company_name'] as String? ?? '',
      domain: json['domain'] as String? ?? json['website'] as String?,
      industry: json['industry'] as String?,
      location: json['location'] as String? ?? json['country'] as String?,
      logoUrl: json['logo_url'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      description: json['description'] as String?,
      isExistingProspect: json['is_existing_prospect'] as bool? ?? false,
      prospectId: json['prospect_id'] as String? ?? json['id'] as String?,
      hasResearch: json['has_research'] as bool? ?? false,
      researchId: json['research_id'] as String?,
    );
  }

  /// Create from existing prospect
  factory CompanySearchResult.fromProspect(
    Map<String, dynamic> json, {
    bool hasResearch = false,
    String? researchId,
  }) {
    return CompanySearchResult(
      name: json['company_name'] as String? ?? '',
      domain: json['website'] as String?,
      industry: json['industry'] as String?,
      location: json['country'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      description: json['description'] as String?,
      isExistingProspect: true,
      prospectId: json['id'] as String?,
      hasResearch: hasResearch,
      researchId: researchId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'domain': domain,
      'industry': industry,
      'location': location,
      'logo_url': logoUrl,
      'linkedin_url': linkedinUrl,
      'description': description,
      'is_existing_prospect': isExistingProspect,
      'prospect_id': prospectId,
      'has_research': hasResearch,
      'research_id': researchId,
    };
  }

  /// Get display domain (without protocol)
  String? get displayDomain {
    if (domain == null || domain!.isEmpty) return null;
    return domain!
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst('www.', '');
  }

  /// Get initial for avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  String toString() => 'CompanySearchResult($name, $domain)';
}


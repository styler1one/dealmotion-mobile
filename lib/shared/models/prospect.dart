/// Prospect model
class Prospect {
  final String id;
  final String companyName;
  final String? website;
  final String? linkedinUrl;
  final String? industry;
  final String? description;
  final String? country;
  final DateTime createdAt;
  final DateTime updatedAt;

  Prospect({
    required this.id,
    required this.companyName,
    this.website,
    this.linkedinUrl,
    this.industry,
    this.description,
    this.country,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Prospect.fromJson(Map<String, dynamic> json) {
    return Prospect(
      id: json['id'] as String,
      companyName: json['company_name'] as String,
      website: json['website'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
      industry: json['industry'] as String?,
      description: json['description'] as String?,
      country: json['country'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'website': website,
      'linkedin_url': linkedinUrl,
      'industry': industry,
      'description': description,
      'country': country,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get display initial for avatar
  String get initial => companyName.isNotEmpty ? companyName[0].toUpperCase() : '?';

  /// Get display website (without protocol)
  String? get displayWebsite {
    if (website == null) return null;
    return website!
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst('www.', '');
  }
}


/// Research model
/// Maps to research_briefs table in database
class Research {
  final String id;
  final String prospectId;
  final String companyName;
  final String? website;  // From joined prospects table
  final String status;
  final String? briefContent;  // Database: brief_content
  final String? language;      // Database: language (not output_language)
  final DateTime createdAt;
  final DateTime? completedAt; // Database: completed_at (not updated_at)

  const Research({
    required this.id,
    required this.prospectId,
    required this.companyName,
    this.website,
    required this.status,
    this.briefContent,
    this.language,
    required this.createdAt,
    this.completedAt,
  });

  factory Research.fromJson(Map<String, dynamic> json) {
    // Handle nested prospect data
    final prospect = json['prospects'] as Map<String, dynamic>?;
    
    return Research(
      id: json['id'] as String,
      prospectId: json['prospect_id'] as String? ?? '',
      companyName: prospect?['company_name'] as String? ?? json['company_name'] as String? ?? '',
      website: prospect?['website'] as String? ?? json['website'] as String?,
      status: json['status'] as String? ?? 'pending',
      briefContent: json['brief_content'] as String? ?? json['full_content'] as String?,  // Database column + API fallback
      language: json['language'] as String?,           // Database column
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null 
          ? DateTime.tryParse(json['completed_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prospect_id': prospectId,
      'company_name': companyName,
      'website': website,
      'status': status,
      'brief_content': briefContent,
      'language': language,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // Backwards compatibility getters
  String? get brief => briefContent;
  String? get fullContent => briefContent;  // API might return as full_content
  String? get outputLanguage => language;
  DateTime get updatedAt => completedAt ?? createdAt;

  /// Is the research completed?
  bool get isCompleted => status == 'completed';

  /// Is the research processing?
  bool get isProcessing => status == 'processing' || status == 'pending';

  /// Is the research failed?
  bool get isFailed => status == 'failed';

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing...';
      case 'pending':
        return 'Starting...';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}


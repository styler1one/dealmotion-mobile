/// Meeting type enum
enum MeetingType {
  discovery,
  demo,
  followUp,
  closing,
  other;

  String get displayName {
    switch (this) {
      case MeetingType.discovery:
        return 'Discovery';
      case MeetingType.demo:
        return 'Demo';
      case MeetingType.followUp:
        return 'Follow-up';
      case MeetingType.closing:
        return 'Closing';
      case MeetingType.other:
        return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case MeetingType.discovery:
        return 'discovery';
      case MeetingType.demo:
        return 'demo';
      case MeetingType.followUp:
        return 'follow_up';
      case MeetingType.closing:
        return 'closing';
      case MeetingType.other:
        return 'other';
    }
  }

  static MeetingType fromString(String? value) {
    switch (value) {
      case 'discovery':
        return MeetingType.discovery;
      case 'demo':
        return MeetingType.demo;
      case 'follow_up':
        return MeetingType.followUp;
      case 'closing':
        return MeetingType.closing;
      default:
        return MeetingType.other;
    }
  }
}

/// Preparation model
/// Maps to meeting_preps table in database
class Preparation {
  final String id;
  final String prospectId;
  final String companyName;        // Database: prospect_company_name
  final String? website;           // From joined prospects table
  final String status;
  final MeetingType meetingType;   // Database: meeting_type
  final String? briefContent;      // Database: brief_content
  final String? language;          // Database: language
  final String? customNotes;       // Database: custom_notes
  final List<String>? contactIds;  // Database: contact_ids
  final String? calendarMeetingId; // Database: calendar_meeting_id (if added via migration)
  final DateTime createdAt;
  final DateTime? completedAt;     // Database: completed_at

  const Preparation({
    required this.id,
    required this.prospectId,
    required this.companyName,
    this.website,
    required this.status,
    required this.meetingType,
    this.briefContent,
    this.language,
    this.customNotes,
    this.contactIds,
    this.calendarMeetingId,
    required this.createdAt,
    this.completedAt,
  });

  factory Preparation.fromJson(Map<String, dynamic> json) {
    // Handle nested prospect data
    final prospect = json['prospects'] as Map<String, dynamic>?;

    return Preparation(
      id: json['id'] as String,
      prospectId: json['prospect_id'] as String? ?? '',
      companyName: prospect?['company_name'] as String? ??
          json['prospect_company_name'] as String? ??  // Database column
          json['company_name'] as String? ??           // Legacy/API fallback
          '',
      website: prospect?['website'] as String? ?? json['website'] as String?,
      status: json['status'] as String? ?? 'pending',
      meetingType: MeetingType.fromString(json['meeting_type'] as String?),
      briefContent: json['brief_content'] as String? ?? json['full_content'] as String?,  // Database column + API fallback
      language: json['language'] as String?,           // Database column
      customNotes: json['custom_notes'] as String?,    // Database column
      contactIds: (json['contact_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      calendarMeetingId: json['calendar_meeting_id'] as String?,
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
      'prospect_company_name': companyName,
      'website': website,
      'status': status,
      'meeting_type': meetingType.apiValue,
      'brief_content': briefContent,
      'language': language,
      'custom_notes': customNotes,
      'contact_ids': contactIds,
      'calendar_meeting_id': calendarMeetingId,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // Backwards compatibility getters
  String? get brief => briefContent;
  String? get fullContent => briefContent;  // API might return as full_content
  String? get outputLanguage => language;
  String? get userNotes => customNotes;
  DateTime get updatedAt => completedAt ?? createdAt;

  /// Is the preparation completed?
  bool get isCompleted => status == 'completed';

  /// Is the preparation processing?
  bool get isProcessing => status == 'processing' || status == 'pending';

  /// Is the preparation failed?
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

/// Contact model for preparation
class Contact {
  final String id;
  final String name;
  final String? role;
  final String? email;
  final String? linkedinUrl;

  const Contact({
    required this.id,
    required this.name,
    this.role,
    this.email,
    this.linkedinUrl,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      email: json['email'] as String?,
      linkedinUrl: json['linkedin_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'linkedin_url': linkedinUrl,
    };
  }
}


import '../../../shared/models/prospect.dart';

/// Contact model for prospect
/// Maps to prospect_contacts table in database
class Contact {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;  // Database: role (not title)
  final String? linkedinUrl;
  final bool isPrimary;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role,
    this.linkedinUrl,
    this.isPrimary = false,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,  // Database column: role
      linkedinUrl: json['linkedin_url'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Note model for prospect
class ProspectNote {
  final String id;
  final String content;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProspectNote({
    required this.id,
    required this.content,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProspectNote.fromJson(Map<String, dynamic> json) {
    return ProspectNote(
      id: json['id'] as String,
      content: json['content'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Document summary for prospect hub
class DocumentSummary {
  final String id;
  final String type; // 'research', 'preparation', 'followup'
  final String title;
  final String status;
  final DateTime createdAt;

  DocumentSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory DocumentSummary.fromJson(Map<String, dynamic> json, String type) {
    return DocumentSummary(
      id: json['id'] as String,
      type: type,
      title: json['company_name'] as String? ?? 
             json['meeting_subject'] as String? ?? 
             'Untitled',
      status: json['status'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Meeting summary for prospect hub
class MeetingSummary {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isPrepared;
  final String? preparationId;

  MeetingSummary({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isPrepared = false,
    this.preparationId,
  });

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Meeting',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      isPrepared: json['preparation_id'] != null,
      preparationId: json['preparation_id'] as String?,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isUpcoming => startTime.isAfter(DateTime.now());
}

/// Full prospect hub data
class ProspectHubData {
  final Prospect prospect;
  final List<Contact> contacts;
  final List<ProspectNote> notes;
  final List<DocumentSummary> research;
  final List<DocumentSummary> preparations;
  final List<DocumentSummary> followups;
  final List<MeetingSummary> upcomingMeetings;

  ProspectHubData({
    required this.prospect,
    this.contacts = const [],
    this.notes = const [],
    this.research = const [],
    this.preparations = const [],
    this.followups = const [],
    this.upcomingMeetings = const [],
  });

  /// Check if research exists
  bool get hasResearch => research.isNotEmpty;

  /// Check if any preparation exists
  bool get hasPreparation => preparations.isNotEmpty;

  /// Check if any followup exists
  bool get hasFollowup => followups.isNotEmpty;

  /// Total document count
  int get totalDocuments => research.length + preparations.length + followups.length;

  /// Journey progress (0-4): Research -> Contacts -> Prep -> Meeting -> Followup
  int get journeyProgress {
    int progress = 0;
    if (hasResearch) progress++;
    if (contacts.isNotEmpty) progress++;
    if (hasPreparation) progress++;
    if (hasFollowup) progress++;
    return progress;
  }
}


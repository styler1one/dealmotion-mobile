/// Followup (Meeting Analysis) model
/// Maps to followups table in database
class Followup {
  final String id;
  final String? prospectId;
  final String? companyName;           // Database: prospect_company_name
  final String? meetingSubject;        // Database: meeting_subject
  final DateTime? meetingDate;         // Database: meeting_date
  final int? audioDurationSeconds;     // Database: audio_duration_seconds
  final String status;
  final String? transcriptionText;     // Database: transcription_text
  final String? executiveSummary;      // Database: executive_summary
  final String? fullSummaryContent;    // Database: full_summary_content
  final String? errorMessage;          // Database: error_message
  final DateTime createdAt;
  final DateTime? completedAt;         // Database: completed_at

  const Followup({
    required this.id,
    this.prospectId,
    this.companyName,
    this.meetingSubject,
    this.meetingDate,
    this.audioDurationSeconds,
    required this.status,
    this.transcriptionText,
    this.executiveSummary,
    this.fullSummaryContent,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  factory Followup.fromJson(Map<String, dynamic> json) {
    // Handle nested prospect data
    final prospect = json['prospects'] as Map<String, dynamic>?;

    return Followup(
      id: json['id'] as String,
      prospectId: json['prospect_id'] as String?,
      companyName: prospect?['company_name'] as String? ??
          json['prospect_company_name'] as String? ??  // Database column
          json['company_name'] as String?,             // Legacy/API fallback
      meetingSubject: json['meeting_subject'] as String?,
      meetingDate: json['meeting_date'] != null
          ? DateTime.tryParse(json['meeting_date'] as String)
          : null,
      audioDurationSeconds: json['audio_duration_seconds'] as int?,  // Database column
      status: json['status'] as String? ?? 'pending',
      transcriptionText: json['transcription_text'] as String?,
      executiveSummary: json['executive_summary'] as String?,         // Database column
      fullSummaryContent: json['full_summary_content'] as String?,    // Database column
      errorMessage: json['error_message'] as String?,
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
      'meeting_subject': meetingSubject,
      'meeting_date': meetingDate?.toIso8601String(),
      'audio_duration_seconds': audioDurationSeconds,
      'status': status,
      'transcription_text': transcriptionText,
      'executive_summary': executiveSummary,
      'full_summary_content': fullSummaryContent,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // Backwards compatibility getters
  int? get meetingDuration => audioDurationSeconds;
  String? get summary => executiveSummary;
  String? get fullContent => fullSummaryContent;
  DateTime get updatedAt => completedAt ?? createdAt;

  /// Get display title
  String get displayTitle {
    if (meetingSubject != null && meetingSubject!.isNotEmpty) {
      return meetingSubject!;
    }
    if (companyName != null && companyName!.isNotEmpty) {
      return 'Meeting with $companyName';
    }
    return 'Meeting Analysis';
  }

  /// Is the followup completed?
  bool get isCompleted => status == 'completed';

  /// Is the followup processing?
  bool get isProcessing =>
      status == 'processing' ||
      status == 'pending' ||
      status == 'transcribing' ||
      status == 'summarizing';

  /// Is the followup failed?
  bool get isFailed => status == 'failed';

  /// Get formatted duration
  String? get formattedDuration {
    if (meetingDuration == null) return null;
    final minutes = meetingDuration! ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return '${hours}h ${remainingMins}m';
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'summarizing':
        return 'Analyzing...';
      case 'transcribing':
        return 'Transcribing...';
      case 'processing':
      case 'pending':
        return 'Processing...';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}


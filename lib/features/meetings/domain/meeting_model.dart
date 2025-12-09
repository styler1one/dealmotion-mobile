/// Calendar Meeting model
/// Maps to calendar_meetings table in database
class Meeting {
  final String id;
  final String? externalEventId;  // Database: external_event_id
  final String title;
  final DateTime startTime;       // Database: start_time
  final DateTime endTime;         // Database: end_time
  final String? location;
  final String? meetingUrl;       // Database: meeting_url
  final String? prospectId;       // Database: prospect_id
  final String? prospectName;     // From joined prospects table
  final String? preparationId;    // Database: preparation_id
  final String? followupId;       // Database: followup_id
  final List<Attendee> attendees; // Database: attendees (JSONB)
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Meeting({
    required this.id,
    this.externalEventId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.meetingUrl,
    this.prospectId,
    this.prospectName,
    this.preparationId,
    this.followupId,
    this.attendees = const [],
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    // Handle nested prospect data
    final prospect = json['prospects'] as Map<String, dynamic>?;

    return Meeting(
      id: json['id'] as String,
      externalEventId: json['external_event_id'] as String?,  // Database column
      title: json['title'] as String? ?? 'Meeting',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      prospectId: json['prospect_id'] as String?,
      prospectName: prospect?['company_name'] as String?,
      preparationId: json['preparation_id'] as String?,
      followupId: json['followup_id'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((a) => Attendee.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_event_id': externalEventId,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'meeting_url': meetingUrl,
      'prospect_id': prospectId,
      'prospect_name': prospectName,
      'preparation_id': preparationId,
      'followup_id': followupId,
      'attendees': attendees.map((a) => a.toJson()).toList(),
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Derived properties
  bool get isOnlineMeeting => meetingUrl != null && meetingUrl!.isNotEmpty;

  /// Check if meeting is happening now
  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Check if meeting is today
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// Check if meeting is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return startTime.year == tomorrow.year &&
        startTime.month == tomorrow.month &&
        startTime.day == tomorrow.day;
  }

  /// Check if meeting is in the past
  bool get isPast => endTime.isBefore(DateTime.now());

  /// Check if meeting is prepared
  bool get isPrepared => preparationId != null;

  /// Check if meeting has been analyzed
  bool get hasFollowup => followupId != null;

  /// Get duration in minutes
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  /// Get formatted duration
  String get formattedDuration {
    final mins = durationMinutes;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (remainingMins == 0) return '${hours}h';
    return '${hours}h ${remainingMins}m';
  }

  /// Get formatted time range
  String get formattedTimeRange {
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  /// Get location display
  String? get displayLocation {
    if (isOnlineMeeting) return 'Online Meeting';
    return location;
  }
}

/// Meeting attendee
class Attendee {
  final String? name;
  final String? email;
  final String? responseStatus;

  const Attendee({
    this.name,
    this.email,
    this.responseStatus,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      name: json['name'] as String?,
      email: json['email'] as String?,
      responseStatus: json['response_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'response_status': responseStatus,
    };
  }

  /// Get display name
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (email != null) return email!.split('@').first;
    return 'Unknown';
  }
}


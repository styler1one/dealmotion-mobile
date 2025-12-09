/// API endpoint definitions
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String apiVersion = '/api/v1';

  // Prospects
  static const String prospects = '$apiVersion/prospects';
  static String prospect(String id) => '$apiVersion/prospects/$id';

  // Research
  static const String research = '$apiVersion/research';
  static const String researchBriefs = '$apiVersion/research/briefs';  // List endpoint
  static const String researchStart = '$apiVersion/research/start';     // Start research
  static String researchBrief(String id) => '$apiVersion/research/$id/brief';
  static String researchStatus(String id) => '$apiVersion/research/$id/status';

  // Preparation
  static const String preparation = '$apiVersion/preparation';
  static const String preparationBriefs = '$apiVersion/preparation/briefs';  // List endpoint
  static const String preparationStart = '$apiVersion/preparation/start';     // Start preparation
  static String meetingPrep(String id) => '$apiVersion/preparation/$id';

  // Follow-up / Meeting Analysis
  static const String followup = '$apiVersion/followup';
  static const String followupList = '$apiVersion/followup/list';    // List endpoint
  static const String followupUpload = '$apiVersion/followup/upload';
  static String followupDetail(String id) => '$apiVersion/followup/$id';

  // Mobile-specific endpoints
  static const String mobileRecordings = '$apiVersion/mobile/recordings';
  static const String mobileRecordingsUpload = '$apiVersion/mobile/recordings/upload';
  static const String mobileRecordingsPending = '$apiVersion/mobile/recordings/pending';
  static String mobileRecording(String id) => '$apiVersion/mobile/recordings/$id';

  // Calendar
  static const String calendarMeetings = '$apiVersion/calendar-meetings';
  static String calendarMeeting(String id) => '$apiVersion/calendar-meetings/$id';

  // User
  static const String profile = '$apiVersion/profile';
  static const String settings = '$apiVersion/settings';
  static const String salesProfile = '$apiVersion/profile/sales';

  // Billing
  static const String billingSubscription = '$apiVersion/billing/subscription';
  static const String billingUsage = '$apiVersion/billing/usage';
}


import 'package:intl/intl.dart';

class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final String? imageUrl;
  final String status;
  final String? rejectReason;
  final String? createdBy; // This will hold the UID
  final String createdByDisplayName; // This will hold the full_name
  final bool isPrivate;
  final int participants;
  final int maxCapacity;

  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    required this.status,
    this.rejectReason,
    this.createdBy,
    required this.createdByDisplayName,
    required this.isPrivate,
    required this.participants,
    required this.maxCapacity,
  });

  /// Factory to convert Supabase JSON to CommunityEvent Object
  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    // Some queries return nested 'requests' objects depending on your join logic
    final masterRequest = json['requests'] is Map ? json['requests'] : {};

    return CommunityEvent(
      id: (json['id'] ?? json['request_id'] ?? masterRequest['request_id'] ?? '').toString(),
      title: json['title'] ?? json['event_title'] ?? 'Untitled Event',
      description: json['description'] ?? masterRequest['description'] ?? 'No description provided.',
      location: json['location'] ?? masterRequest['location'] ?? 'No Location',

      // Date Parsing
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'])
          : (json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now()),

      // Time Formatting using helper
      startTime: _formatTime(json['start_time'] ?? masterRequest['start_time']),
      endTime: _formatTime(json['end_time'] ?? masterRequest['end_time']),

      imageUrl: json['image_url'] ?? masterRequest['image_url'],
      status: json['status'] ?? masterRequest['status'] ?? 'pending',

      // Mapping Reject Reason (from admin_new decisions)
      rejectReason: json['reject_reason'] ?? masterRequest['reject_reason'],

      // User Identification
      createdBy: (json['created_by'] ?? json['user_id'] ?? masterRequest['user_id'])?.toString(),

      // Pulling the full_name we passed from the Calendar/Create screen
      createdByDisplayName: json['created_by_name'] ?? 'Resident',

      isPrivate: json['is_private'] ?? false,
      participants: json['participants'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 20,
    );
  }

  /// Helper to ensure time is always HH:mm
  static String _formatTime(dynamic time) {
    if (time == null) return "00:00";
    String t = time.toString();

    // If Supabase returns HH:mm:ss, we strip the seconds
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
      }
    }
    return t;
  }

  /// Helper getter for UI
  bool get isFull => participants >= maxCapacity;

  /// Formats the date for display (e.g., 12 Oct 2026)
  String get formattedDate => DateFormat('dd MMM yyyy').format(eventDate);

  /// Convert Object back to JSON for database updates
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'image_url': imageUrl,
      'status': status,
      'reject_reason': rejectReason,
      'created_by_name': createdByDisplayName,
      'is_private': isPrivate,
      'max_capacity': maxCapacity,
      'participants': participants,
    };
  }
}
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
  final String? createdBy; // The user_id UUID
  final String createdByDisplayName;
  final bool isPrivate;

  // NEW FIELDS FOR CAPACITY
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
    this.createdBy,
    required this.createdByDisplayName,
    required this.isPrivate,
    required this.participants, // Added
    required this.maxCapacity,  // Added
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    // Safely extract nested data from the 'requests' join if it exists
    final masterRequest = json['requests'] is Map ? json['requests'] : {};

    return CommunityEvent(
      // 1. UUID Handling
      id: (json['id'] ?? json['request_id'] ?? masterRequest['request_id'] ?? '').toString(),

      // 2. Field Mapping
      title: json['event_title'] ?? json['title'] ?? 'Untitled Event',
      description: json['description'] ?? masterRequest['description'] ?? '',
      location: json['location'] ?? 'No Location',

      // 3. Date Parsing
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'])
          : (json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now()),

      // 4. Time Parsing
      startTime: _formatTime(json['start_time']),
      endTime: _formatTime(json['end_time']),

      imageUrl: json['image_url'],

      // 5. Status & Metadata
      status: masterRequest['status'] ?? json['status'] ?? 'pending',
      createdBy: masterRequest['user_id'] ?? json['user_id'],
      createdByDisplayName: json['created_by_name'] ?? 'Resident',
      isPrivate: json['is_private'] ?? false,

      // 6. CAPACITY MAPPING (Crucial for testing)
      participants: json['participants'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 20, // Default to 20 if not specified
    );
  }

  // Helper to ensure time strings are consistently formatted
  static String _formatTime(dynamic time) {
    if (time == null) return "00:00";
    String t = time.toString();
    if (t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
      }
    }
    return t;
  }

  // Method to check if the event is full
  bool get isFull => participants >= maxCapacity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'image_url': imageUrl,
      'created_by_name': createdByDisplayName,
      'is_private': isPrivate,
      'max_capacity': maxCapacity,
      'participants': participants,
    };
  }
}
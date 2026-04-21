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
  final String? rejectReason; // NEW FIELD
  final String? createdBy;
  final String createdByDisplayName;
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
    this.rejectReason, // ADDED
    this.createdBy,
    required this.createdByDisplayName,
    required this.isPrivate,
    required this.participants,
    required this.maxCapacity,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    final masterRequest = json['requests'] is Map ? json['requests'] : {};

    return CommunityEvent(
      id: (json['id'] ?? json['request_id'] ?? masterRequest['request_id'] ?? '').toString(),
      title: json['event_title'] ?? json['title'] ?? 'Untitled Event',
      description: json['description'] ?? masterRequest['description'] ?? '',
      location: json['location'] ?? 'No Location',
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'])
          : (json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now()),
      startTime: _formatTime(json['start_time']),
      endTime: _formatTime(json['end_time']),
      imageUrl: json['image_url'],
      status: masterRequest['status'] ?? json['status'] ?? 'pending',

      // MAPPING REJECT REASON
      rejectReason: masterRequest['reject_reason'] ?? json['reject_reason'],

      createdBy: masterRequest['user_id'] ?? json['user_id'],
      createdByDisplayName: json['created_by_name'] ?? 'Resident',
      isPrivate: json['is_private'] ?? false,
      participants: json['participants'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 20,
    );
  }

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
      'status': status,
      'reject_reason': rejectReason, // ADDED
      'created_by_name': createdByDisplayName,
      'is_private': isPrivate,
      'max_capacity': maxCapacity,
      'participants': participants,
    };
  }
}
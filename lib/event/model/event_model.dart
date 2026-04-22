
class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final String? imageUrl;

  /// The UUID of the resident/admin who created the event.
  /// Populated from events.user_id (or flattened from requests.user_id).
  final String userId;

  final String createdByName;

  /// true = private event, false = public event.
  final bool isPrivate;

  final DateTime createdAt;
  final int maxCapacity;

  /// Live participant count. Nullable because event_requests rows
  /// (pending/rejected) may not have this column.
  final int? participants;

  final String? processedBy;

  // ── Status fields ──────────────────────────
  // Flattened in by EventService from the joined `requests` table.
  final String status;
  final String? rejectReason;

  // Legacy field — some screens reference event.createdBy.
  // Always mirrors userId so old call-sites keep working.
  String? get createdBy => userId.isNotEmpty ? userId : null;

  // Helper used by EventDetailsScreen
  String get createdByDisplayName =>
      createdByName.isNotEmpty ? createdByName : 'Resident';

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    required this.userId,
    required this.createdByName,
    this.isPrivate = false,
    required this.createdAt,
    required this.maxCapacity,
    this.participants,
    this.processedBy,
    this.status = 'pending',
    this.rejectReason,
  });

  // ── fromJson ───────────────────────────────
  // Called by EventService._mapSingleResponseToEvent() after it flattens
  // the nested `requests` sub-object into the top-level map.
  //
  // Key mappings (DB column → Dart field):
  //   event_requests.date        → eventDate
  //   event_requests.event_title → title   (history / pending view)
  //   events.title               → title   (live calendar view)
  //   events.user_id             → userId  (may also come from requests.user_id)
  //   requests.status            → status  (flattened by service)
  //   requests.reject_reason     → rejectReason
  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    // ── id ──────────────────────────────────
    final id = (json['id'] ?? json['request_id'] ?? '').toString();

    // ── title ───────────────────────────────
    // event_requests table uses 'event_title'; events table uses 'title'
    final title = (json['event_title'] ?? json['title'] ?? '').toString();

    // ── date ────────────────────────────────
    // event_requests uses 'date'; events table uses 'event_date'
    final rawDate = json['event_date'] ?? json['date'];
    final eventDate = _parseDate(rawDate);

    // ── times ───────────────────────────────
    final startTime = _parseTime(json['start_time']);
    final endTime = _parseTime(json['end_time']);

    // ── userId ──────────────────────────────
    final userId = (json['user_id'] ?? '').toString();

    return CommunityEvent(
      id: id,
      title: title,
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      eventDate: eventDate,
      startTime: startTime,
      endTime: endTime,
      imageUrl: json['image_url']?.toString(),
      userId: userId,
      createdByName: (json['created_by_name'] ?? '').toString(),
      isPrivate: json['is_private'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']),
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 0,
      participants: (json['participants'] as num?)?.toInt(),
      processedBy: json['processed_by']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      rejectReason: json['reject_reason']?.toString(),
    );
  }

  // Convenience alias so any call-site using fromMap() also compiles.
  factory CommunityEvent.fromMap(Map<String, dynamic> map) =>
      CommunityEvent.fromJson(map);

  // ── copyWith ───────────────────────────────
  CommunityEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? eventDate,
    String? startTime,
    String? endTime,
    String? imageUrl,
    String? userId,
    String? createdByName,
    bool? isPrivate,
    DateTime? createdAt,
    int? maxCapacity,
    int? participants,
    String? processedBy,
    String? status,
    String? rejectReason,
  }) {
    return CommunityEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
      createdByName: createdByName ?? this.createdByName,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      participants: participants ?? this.participants,
      processedBy: processedBy ?? this.processedBy,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }

  // ── private helpers ────────────────────────

  static DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString()) ?? DateTime.now();
  }

  /// Normalises a time value that may come back from Supabase as
  /// "HH:mm:ss" or already as "HH:mm".
  static String _parseTime(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    // If it looks like HH:mm:ss, drop the seconds part
    if (RegExp(r'^\d{2}:\d{2}:\d{2}').hasMatch(s)) {
      return s.substring(0, 5);
    }
    return s;
  }
}
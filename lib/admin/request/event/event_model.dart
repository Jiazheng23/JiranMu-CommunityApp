class CommunityEvent {
  final int id;
  final String title;
  final String description;
  final DateTime eventDate;
  final String startTime;
  final String location;
  final bool isPrivate;
  final String? imageUrl;
  final String creatorEmail; // This is the 'created_by' from your table
  final String status;        // To track 'pending'/'approved'
  final String creatorName;  // To show who proposed it
  final String? adminNote;   // Optional feedback from admin

  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.location,
    required this.isPrivate,
    this.imageUrl,
    required this.creatorEmail,
    required this.status,
    required this.creatorName,
    this.adminNote,
  });

  // This function converts Supabase data (JSON) into this Dart object
  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      eventDate: DateTime.parse(json['event_date']),
      startTime: json['start_time'],
      location: json['location'],
      isPrivate: json['is_private'],
      imageUrl: json['image_url'],
      creatorEmail: json['created_by'], // Make sure this matches your column name
      status: json['status'] ?? 'pending',
      creatorName: json['created_by_name'],
      adminNote: json['admin_note'],
    );
  }
}
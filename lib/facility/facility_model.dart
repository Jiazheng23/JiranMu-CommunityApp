class FacilityModel {
  const FacilityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.capacity,
    required this.openTime,
    required this.closeTime,
    required this.bookingMode,
    required this.isActive,
    required this.slotDurationMinutes,
    required this.maxDurationMinutes,
    required this.purposeRequired,
    required this.isShared,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String location;
  final int capacity;
  final String openTime;
  final String closeTime;
  final String bookingMode;
  final bool isActive;

  final int slotDurationMinutes;
  final int? maxDurationMinutes;
  final bool purposeRequired;
  final bool isShared;

  bool get isInstantBooking => bookingMode == 'instant';
  bool get requiresApproval => bookingMode == 'approval';
  bool get hasMaxDuration => maxDurationMinutes != null;

  factory FacilityModel.fromMap(Map<String, dynamic> map) {
    return FacilityModel(
      id: map['id'] as String,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      location: map['location'] ?? '',
      capacity: (map['capacity'] ?? 0) as int,
      openTime: map['open_time']?.toString() ?? '',
      closeTime: map['close_time']?.toString() ?? '',
      bookingMode: map['booking_mode'] ?? 'instant',
      isActive: map['is_active'] ?? true,
      slotDurationMinutes: (map['slot_duration_minutes'] ?? 60) as int,
      maxDurationMinutes: map['max_duration_minutes'] as int?,
      purposeRequired: map['purpose_required'] ?? false,
      isShared: map['is_shared'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'location': location,
      'capacity': capacity,
      'open_time': openTime,
      'close_time': closeTime,
      'booking_mode': bookingMode,
      'is_active': isActive,
      'slot_duration_minutes': slotDurationMinutes,
      'max_duration_minutes': maxDurationMinutes,
      'purpose_required': purposeRequired,
      'is_shared': isShared,
    };
  }
}
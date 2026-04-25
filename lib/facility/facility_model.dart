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
    required this.usageType,
    required this.isActive,
    required this.maxDurationMinutes,
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
  final String usageType;
  final bool isActive;
  final int? maxDurationMinutes;
  final bool isShared;

  bool get isInstantBooking => bookingMode == 'instant';
  bool get requiresApproval => bookingMode == 'approval';

  bool get isFacilityType => usageType == 'facility';
  bool get isVenueType => usageType == 'event';

  factory FacilityModel.fromMap(Map<String, dynamic> map) {
    return FacilityModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      openTime: map['open_time']?.toString() ?? '',
      closeTime: map['close_time']?.toString() ?? '',
      bookingMode: map['booking_mode']?.toString() ?? 'instant',
      usageType: map['usage_type']?.toString() ?? 'facility',
      isActive: map['is_active'] ?? true,
      maxDurationMinutes: (map['max_duration_minutes'] as num?)?.toInt(),
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
      'usage_type': usageType,
      'is_active': isActive,
      'max_duration_minutes': maxDurationMinutes,
      'is_shared': isShared,
    };
  }
}
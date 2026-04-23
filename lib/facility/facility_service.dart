import 'dart:io';

import 'package:assignment/facility/facility_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacilityUnavailableSlot {
  const FacilityUnavailableSlot({
    required this.id,
    required this.facilityId,
    required this.blockDate,
    required this.startTime,
    required this.endTime,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String facilityId;
  final String blockDate;
  final String startTime;
  final String endTime;
  final String? reason;
  final String? createdAt;

  factory FacilityUnavailableSlot.fromMap(Map<String, dynamic> map) {
    return FacilityUnavailableSlot(
      id: map['id']?.toString() ?? '',
      facilityId: map['facility_id']?.toString() ?? '',
      blockDate: map['block_date']?.toString() ?? '',
      startTime: map['start_time']?.toString() ?? '',
      endTime: map['end_time']?.toString() ?? '',
      reason: map['reason']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }
}

class FacilityService {
  FacilityService();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<FacilityModel>> fetchFacilities({
    bool activeOnly = true,
    String usageType = 'facility',
    String? bookingMode,
  }) async {
    var query = _supabase.from('facilities').select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    query = query.eq('usage_type', usageType);

    if (bookingMode != null && bookingMode.trim().isNotEmpty) {
      query = query.eq('booking_mode', bookingMode);
    }

    final data = await query.order('name');

    return (data as List)
        .map((item) => FacilityModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FacilityModel>> fetchAllFacilities() async {
    final data = await _supabase
        .from('facilities')
        .select()
        .order('created_at', ascending: false);

    return (data as List)
        .map((item) => FacilityModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<String?> uploadFacilityImage(File imageFile) async {
    try {
      final fileName = 'facility_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('facility_images').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      return _supabase.storage.from('facility_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Facility image upload error: $e');
      return null;
    }
  }

  Future<void> createFacility({
    required String name,
    required String description,
    required String imageUrl,
    required String location,
    required int capacity,
    required String openTime,
    required String closeTime,
    required String bookingMode,
    required String usageType,
    required bool isActive,
    int? maxDurationMinutes,
    required bool isShared,
  }) async {
    await _supabase.from('facilities').insert({
      'name': name,
      'description': description.isEmpty ? null : description,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'location': location,
      'capacity': capacity,
      'open_time': openTime,
      'close_time': closeTime,
      'booking_mode': bookingMode,
      'usage_type': usageType,
      'is_active': isActive,
      'max_duration_minutes': maxDurationMinutes,
      'is_shared': isShared,
    });
  }

  Future<void> updateFacility({
    required String id,
    required String name,
    required String description,
    required String imageUrl,
    required String location,
    required int capacity,
    required String openTime,
    required String closeTime,
    required String bookingMode,
    required String usageType,
    required bool isActive,
    int? maxDurationMinutes,
    required bool isShared,
  }) async {
    await _supabase.from('facilities').update({
      'name': name,
      'description': description.isEmpty ? null : description,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'location': location,
      'capacity': capacity,
      'open_time': openTime,
      'close_time': closeTime,
      'booking_mode': bookingMode,
      'usage_type': usageType,
      'is_active': isActive,
      'max_duration_minutes': maxDurationMinutes,
      'is_shared': isShared,
    }).eq('id', id);
  }

  Future<void> updateFacilityActiveStatus({
    required String id,
    required bool isActive,
  }) async {
    await _supabase
        .from('facilities')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<int> fetchUpcomingApprovedBookingCount(String facilityId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final data = await _supabase
        .from('facility_bookings')
        .select('id')
        .eq('facility_id', facilityId)
        .eq('status', 'approved')
        .gte('booking_date', today);

    return (data as List).length;
  }

  Future<void> deactivateFacilityAndCancelUpcomingBookings({
    required String facilityId,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Cancellation reason is required.');
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    final nowIso = DateTime.now().toIso8601String();

    await _supabase
        .from('facility_bookings')
        .update({
      'status': 'cancelled',
      'cancel_reason': trimmedReason,
      'cancelled_at': nowIso,
    })
        .eq('facility_id', facilityId)
        .eq('status', 'approved')
        .gte('booking_date', today);

    await _supabase
        .from('facilities')
        .update({'is_active': false})
        .eq('id', facilityId);
  }

  Future<List<FacilityUnavailableSlot>> fetchFacilityUnavailableSlots(
      String facilityId,
      ) async {
    final data = await _supabase
        .from('facility_unavailable_slots')
        .select()
        .eq('facility_id', facilityId)
        .order('block_date', ascending: true)
        .order('start_time', ascending: true);

    return (data as List)
        .map(
          (item) =>
          FacilityUnavailableSlot.fromMap(item as Map<String, dynamic>),
    )
        .toList();
  }

  Future<void> createFacilityUnavailableSlot({
    required FacilityModel facility,
    required DateTime blockDate,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    final dateOnly = blockDate.toIso8601String().split('T').first;

    final startMinutes = _parseTimeToMinutes(startTime);
    final endMinutes = _parseTimeToMinutes(endTime);
    final openMinutes = _parseTimeToMinutes(facility.openTime);
    final closeMinutes = _parseTimeToMinutes(facility.closeTime);

    if (startMinutes == null ||
        endMinutes == null ||
        openMinutes == null ||
        closeMinutes == null) {
      throw Exception('Invalid blocked time range.');
    }

    if (endMinutes <= startMinutes) {
      throw Exception('End time must be later than start time.');
    }

    if (startMinutes < openMinutes || endMinutes > closeMinutes) {
      throw Exception(
        'Blocked time must be within facility operating hours.',
      );
    }

    final approvedBookings = await _supabase
        .from('facility_bookings')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('status', 'approved');

    final hasApprovedOverlap = approvedBookings.any((item) {
      final bookedStart =
      _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final bookedEnd = _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (bookedStart == null || bookedEnd == null) return false;

      return _hasTimeOverlap(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        otherStartMinutes: bookedStart,
        otherEndMinutes: bookedEnd,
      );
    });

    if (hasApprovedOverlap) {
      throw Exception(
        'This blocked slot overlaps with existing approved bookings.',
      );
    }

    final existingBlocks = await _supabase
        .from('facility_unavailable_slots')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('block_date', dateOnly);

    final hasBlockedOverlap = existingBlocks.any((item) {
      final blockedStart =
      _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final blockedEnd =
      _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (blockedStart == null || blockedEnd == null) return false;

      return _hasTimeOverlap(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        otherStartMinutes: blockedStart,
        otherEndMinutes: blockedEnd,
      );
    });

    if (hasBlockedOverlap) {
      throw Exception('This blocked slot overlaps with another blocked slot.');
    }

    await _supabase.from('facility_unavailable_slots').insert({
      'facility_id': facility.id,
      'block_date': dateOnly,
      'start_time': startTime,
      'end_time': endTime,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
    });
  }

  Future<void> deleteFacilityUnavailableSlot(String slotId) async {
    await _supabase
        .from('facility_unavailable_slots')
        .delete()
        .eq('id', slotId);
  }

  Future<List<Map<String, dynamic>>> fetchUnavailableRanges({
    required FacilityModel facility,
    required DateTime bookingDate,
  }) async {
    final dateOnly = bookingDate.toIso8601String().split('T').first;

    final approvedBookings = await _supabase
        .from('facility_bookings')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('status', 'approved');

    final blockedSlots = await _supabase
        .from('facility_unavailable_slots')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('block_date', dateOnly);

    final bookingRanges = List<Map<String, dynamic>>.from(approvedBookings)
        .map(
          (item) => {
        'start_time': item['start_time'],
        'end_time': item['end_time'],
        'source': 'booking',
      },
    )
        .toList();

    final blockedRanges = List<Map<String, dynamic>>.from(blockedSlots)
        .map(
          (item) => {
        'start_time': item['start_time'],
        'end_time': item['end_time'],
        'source': 'blocked',
      },
    )
        .toList();

    return [...bookingRanges, ...blockedRanges];
  }

  Future<void> submitFacilityBooking({
    required FacilityModel facility,
    required DateTime bookingDate,
    required String startTime,
    required String endTime,
    required int participants,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final dateOnly = bookingDate.toIso8601String().split('T').first;

    final startMinutes = _parseTimeToMinutes(startTime);
    final endMinutes = _parseTimeToMinutes(endTime);

    if (startMinutes == null || endMinutes == null) {
      throw Exception('Invalid booking time');
    }

    if (endMinutes <= startMinutes) {
      throw Exception('End time must be later than start time');
    }

    if (facility.maxDurationMinutes != null &&
        (endMinutes - startMinutes) > facility.maxDurationMinutes!) {
      throw Exception(
        'Maximum duration for ${facility.name} is '
            '${facility.maxDurationMinutes! ~/ 60} hour(s).',
      );
    }

    final blockedSlots = await _supabase
        .from('facility_unavailable_slots')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('block_date', dateOnly);

    final overlapsBlockedSlot = blockedSlots.any((item) {
      final blockedStart =
      _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final blockedEnd =
      _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (blockedStart == null || blockedEnd == null) return false;

      return _hasTimeOverlap(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        otherStartMinutes: blockedStart,
        otherEndMinutes: blockedEnd,
      );
    });

    if (overlapsBlockedSlot) {
      throw Exception(
        'This facility is unavailable for the selected time range.',
      );
    }

    final approvedBookings = await _supabase
        .from('facility_bookings')
        .select('participants, start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('status', 'approved');

    if (facility.isShared) {
      int usedCapacity = 0;

      for (final row in approvedBookings) {
        final existingStart =
        _parseTimeToMinutes(row['start_time']?.toString() ?? '');
        final existingEnd =
        _parseTimeToMinutes(row['end_time']?.toString() ?? '');

        if (existingStart == null || existingEnd == null) continue;

        final overlap = _hasTimeOverlap(
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          otherStartMinutes: existingStart,
          otherEndMinutes: existingEnd,
        );

        if (overlap) {
          usedCapacity += 1;
        }
      }

      if (usedCapacity + 1 > facility.capacity) {
        final remaining = facility.capacity - usedCapacity;
        throw Exception(
          remaining > 0
              ? 'Selected time range is almost full. Remaining capacity: $remaining'
              : 'Selected time range is full. Please choose another time.',
        );
      }

      await _supabase.from('facility_bookings').insert({
        'facility_id': facility.id,
        'resident_id': user.id,
        'booking_date': dateOnly,
        'start_time': startTime,
        'end_time': endTime,
        'participants': 1,
        'status': 'approved',
      });
      return;
    }

    final hasApprovedOverlap = approvedBookings.any((item) {
      final bookedStart =
      _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final bookedEnd = _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (bookedStart == null || bookedEnd == null) return false;

      return _hasTimeOverlap(
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        otherStartMinutes: bookedStart,
        otherEndMinutes: bookedEnd,
      );
    });

    if (hasApprovedOverlap) {
      throw Exception('This time range has already been booked.');
    }

    await _supabase.from('facility_bookings').insert({
      'facility_id': facility.id,
      'resident_id': user.id,
      'booking_date': dateOnly,
      'start_time': startTime,
      'end_time': endTime,
      'participants': 1,
      'status': 'approved',
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyBookingHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _supabase
        .from('facility_bookings')
        .select('''
          id,
          booking_date,
          start_time,
          end_time,
          participants,
          status,
          cancel_reason,
          cancelled_at,
          created_at,
          facilities(
            id,
            name,
            location,
            booking_mode,
            is_shared
          )
        ''')
        .eq('resident_id', user.id)
        .inFilter('status', ['approved', 'cancelled'])
        .order('booking_date', ascending: false)
        .order('start_time', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchMyConfirmedBookings() async {
    return fetchMyBookingHistory();
  }

  Future<List<Map<String, dynamic>>> fetchMyFacilityRequests() async {
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchPendingFacilityRequestsForAdmin() async {
    return [];
  }

  Future<void> approveFacilityRequest(String requestId) async {
    return;
  }

  Future<void> rejectFacilityRequest({
    required String requestId,
    required String rejectReason,
  }) async {
    return;
  }

  String formatDbTimeTo12Hour(String raw) {
    final totalMinutes = _parseTimeToMinutes(raw);
    if (totalMinutes == null) return raw;

    final hour24 = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  int? _parseTimeToMinutes(String raw) {
    if (raw.trim().isEmpty) return null;

    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return (hour * 60) + minute;
  }

  bool _hasTimeOverlap({
    required int startMinutes,
    required int endMinutes,
    required int otherStartMinutes,
    required int otherEndMinutes,
  }) {
    return !(endMinutes <= otherStartMinutes ||
        startMinutes >= otherEndMinutes);
  }
}
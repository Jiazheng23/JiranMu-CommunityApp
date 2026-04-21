import 'package:assignment/facility/facility_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacilityService {
  FacilityService();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<FacilityModel>> fetchFacilities({bool activeOnly = true}) async {
    var query = _supabase.from('facilities').select();

    if (activeOnly) {
      query = query.eq('is_active', true);
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

  Future<void> createFacility({
    required String name,
    required String description,
    required String imageUrl,
    required String location,
    required int capacity,
    required String openTime,
    required String closeTime,
    required String bookingMode,
    required bool isActive,
    required int slotDurationMinutes,
    int? maxDurationMinutes,
    required bool purposeRequired,
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
      'is_active': isActive,
      'slot_duration_minutes': slotDurationMinutes,
      'max_duration_minutes': maxDurationMinutes,
      'purpose_required': purposeRequired,
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
    required bool isActive,
    required int slotDurationMinutes,
    int? maxDurationMinutes,
    required bool purposeRequired,
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
      'is_active': isActive,
      'slot_duration_minutes': slotDurationMinutes,
      'max_duration_minutes': maxDurationMinutes,
      'purpose_required': purposeRequired,
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

  Future<List<Map<String, dynamic>>> fetchUnavailableRanges({
    required FacilityModel facility,
    required DateTime bookingDate,
  }) async {
    final dateOnly = bookingDate.toIso8601String().split('T').first;

    final data = await _supabase
        .from('facility_bookings')
        .select('start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('status', 'approved');

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> submitFacilityBooking({
    required FacilityModel facility,
    required DateTime bookingDate,
    required String startTime,
    required String endTime,
    required int participants,
    String? purpose,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final dateOnly = bookingDate.toIso8601String().split('T').first;
    final cleanedPurpose =
    purpose?.trim().isNotEmpty == true ? purpose!.trim() : null;

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
        'Maximum duration for ${facility.name} is ${facility.maxDurationMinutes! ~/ 60} hour(s).',
      );
    }

    final slotLabel =
        '${_formatDbTimeTo12Hour(startTime)} - ${_formatDbTimeTo12Hour(endTime)}';

    final approvedBookings = await _supabase
        .from('facility_bookings')
        .select('participants, start_time, end_time')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('status', 'approved');

    if (facility.isInstantBooking && facility.isShared) {
      int usedCapacity = 0;

      for (final row in approvedBookings) {
        final existingStart =
        _parseTimeToMinutes(row['start_time']?.toString() ?? '');
        final existingEnd = _parseTimeToMinutes(row['end_time']?.toString() ?? '');

        if (existingStart == null || existingEnd == null) continue;

        final overlap = !(endMinutes <= existingStart || startMinutes >= existingEnd);

        if (overlap) {
          usedCapacity += ((row['participants'] ?? 1) as int);
        }
      }

      if (usedCapacity + participants > facility.capacity) {
        final remaining = facility.capacity - usedCapacity;
        throw Exception(
          remaining > 0
              ? 'Selected time range is almost full. Remaining capacity: $remaining'
              : 'Selected time range is full. Please choose another time.',
        );
      }

      await _supabase.from('facility_bookings').insert({
        'request_id': null,
        'facility_id': facility.id,
        'resident_id': user.id,
        'booking_date': dateOnly,
        'start_time': startTime,
        'end_time': endTime,
        'slot_label': slotLabel,
        'participants': participants,
        'purpose': cleanedPurpose,
        'status': 'approved',
      });

      return;
    }

    final hasApprovedOverlap = approvedBookings.any((item) {
      final bookedStart = _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final bookedEnd = _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (bookedStart == null || bookedEnd == null) return false;

      return !(endMinutes <= bookedStart || startMinutes >= bookedEnd);
    });

    if (hasApprovedOverlap) {
      throw Exception('This time range has already been booked.');
    }

    if (facility.isInstantBooking) {
      await _supabase.from('facility_bookings').insert({
        'request_id': null,
        'facility_id': facility.id,
        'resident_id': user.id,
        'booking_date': dateOnly,
        'start_time': startTime,
        'end_time': endTime,
        'slot_label': slotLabel,
        'participants': 1,
        'purpose': cleanedPurpose,
        'status': 'approved',
      });
      return;
    }

    final myExistingRequests = await _supabase
        .from('facility_requests')
        .select('start_time, end_time, requests!inner(user_id, status)')
        .eq('facility_id', facility.id)
        .eq('booking_date', dateOnly)
        .eq('requests.user_id', user.id)
        .inFilter('requests.status', ['pending', 'approved']);

    final hasMyOwnPendingOverlap = myExistingRequests.any((item) {
      final bookedStart = _parseTimeToMinutes(item['start_time']?.toString() ?? '');
      final bookedEnd = _parseTimeToMinutes(item['end_time']?.toString() ?? '');

      if (bookedStart == null || bookedEnd == null) return false;

      return !(endMinutes <= bookedStart || startMinutes >= bookedEnd);
    });

    if (hasMyOwnPendingOverlap) {
      throw Exception(
        'You already submitted a booking request for this time range. Please wait for approval.',
      );
    }

    String? requestId;

    try {
      final requestResponse = await _supabase
          .from('requests')
          .insert({
        'user_id': user.id,
        'type': 'facility',
        'title': 'Facility Request - ${facility.name}',
        'description': cleanedPurpose ?? 'Facility booking request',
        'status': 'pending',
      })
          .select('request_id')
          .single();

      requestId = requestResponse['request_id'] as String;

      await _supabase.from('facility_requests').insert({
        'request_id': requestId,
        'facility_id': facility.id,
        'booking_date': dateOnly,
        'start_time': startTime,
        'end_time': endTime,
        'slot_label': slotLabel,
        'participants': participants,
        'purpose': cleanedPurpose,
      });
    } catch (e) {
      if (requestId != null) {
        await _supabase.from('requests').delete().eq('request_id', requestId);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyConfirmedBookings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _supabase
        .from('facility_bookings')
        .select('''
        id,
        request_id,
        booking_date,
        start_time,
        end_time,
        slot_label,
        participants,
        purpose,
        status,
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
        .eq('status', 'approved')
        .order('booking_date', ascending: false)
        .order('start_time', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchMyFacilityRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final data = await _supabase
        .from('requests')
        .select('''
          request_id,
          status,
          created_at,
          reject_reason,
          facility_requests(
            booking_date,
            start_time,
            end_time,
            slot_label,
            participants,
            purpose,
            facilities(name, location, booking_mode)
          )
        ''')
        .eq('user_id', user.id)
        .eq('type', 'facility')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchPendingFacilityRequestsForAdmin() async {
    final data = await _supabase
        .from('requests')
        .select('''
          request_id,
          user_id,
          status,
          created_at,
          title,
          description,
          facility_requests(
            facility_id,
            booking_date,
            start_time,
            end_time,
            slot_label,
            participants,
            purpose,
            facilities(id, name, location, booking_mode)
          )
        ''')
        .eq('type', 'facility')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> approveFacilityRequest(String requestId) async {
    await _supabase.from('requests').update({
      'status': 'approved',
      'respond_time': DateTime.now().toIso8601String(),
      'reject_reason': null,
    }).eq('request_id', requestId);
  }

  Future<void> rejectFacilityRequest({
    required String requestId,
    required String rejectReason,
  }) async {
    await _supabase.from('requests').update({
      'status': 'rejected',
      'respond_time': DateTime.now().toIso8601String(),
      'reject_reason': rejectReason,
    }).eq('request_id', requestId);
  }

  String _formatDbTimeTo12Hour(String raw) {
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
}

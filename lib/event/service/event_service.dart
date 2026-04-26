import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/event_model.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class EventService {
  final supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // 1. UPLOAD IMAGE
  // ─────────────────────────────────────────────

  Future<String?> uploadEventImage(File imageFile) async {
    try {
      final String fileName =
          'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('event_images').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );
      return supabase.storage.from('event_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 2. FACILITY METHODS
  // ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActiveFacilities() async {
    try {
      final response = await supabase
          .from('facilities')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Fetch Facilities Error: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // 3. CREATE EVENT REQUEST
  // ─────────────────────────────────────────────

  Future<void> createEvent({
    required Map<String, dynamic> eventData,
    required String userRole,
  }) async {
    try {
      final String? userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User must be logged in to create events.");
      }

      final response = await supabase.from('requests').insert({
        'user_id': userId,
        'type': 'booking',
        'title': eventData['title'],
        'description': eventData['description'],
        'status': (userRole == 'admin') ? 'approved' : 'pending',
      }).select().single();

      final String newRequestId = response['request_id'].toString();

      await supabase.from('event_requests').insert({
        'request_id': newRequestId,
        'event_title': eventData['title'],
        'location': eventData['location'],
        'date': eventData['event_date'],
        'start_time': eventData['start_time'],
        'end_time': eventData['end_time'],
        'image_url': eventData['image_url'],
        'participants': 0,
        'max_capacity': eventData['max_capacity'] ?? 20,
        'created_by_name': eventData['created_by_name'] ?? 'Resident',
        'is_private': eventData['is_private'] ?? false,
      });

      if (userRole == 'admin') {
        await approveAndPromoteRequest(newRequestId);
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 4. APPROVE & PROMOTE
  // ─────────────────────────────────────────────

  Future<void> approveAndPromoteRequest(String requestId) async {
    try {
      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);

      final details = await supabase
          .from('event_requests')
          .select('*, requests!inner(user_id, description)')
          .eq('request_id', requestId)
          .single();

      await supabase.from('events').insert({
        'id': requestId,
        'title': details['event_title'],
        'description': details['requests']['description'],
        'location': details['location'],
        'event_date': details['date'],
        'start_time': details['start_time'],
        'end_time': details['end_time'],
        'image_url': details['image_url'],
        'user_id': details['requests']['user_id'],
        'created_by_name': details['created_by_name'] ?? 'Resident',
        'is_private': details['is_private'] ?? false,
        'max_capacity': details['max_capacity'] ?? 20,
        'participants': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Approval Error: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 5. FETCHING METHODS
  // ─────────────────────────────────────────────

  Future<List<CommunityEvent>> fetchAllEvents(
      {int? limit, bool upcomingOnly = true}) async {
    try {
      var query = supabase
          .from('events')
          .select(
          '*, requests!inner(status, user_id, description, reject_reason)')
          .eq('is_private', false);

      if (upcomingOnly) {
        final String today = DateTime.now().toIso8601String().split('T')[0];
        query = query.gte('event_date', today);
      }

      final response = await (limit != null
          ? query.order('event_date', ascending: true).limit(limit)
          : query.order('event_date', ascending: true));

      return _mapResponseToEventList(response);
    } catch (e) {
      debugPrint("Fetch All Events Error: $e");
      return [];
    }
  }

  Future<List<CommunityEvent>> fetchMyApprovedEvents(String userId) async {
    try {
      final response = await supabase
          .from('events')
          .select(
          'id, title, description, location, event_date, start_time, '
              'end_time, image_url, user_id, created_by_name, is_private, '
              'created_at, max_capacity, participants, processed_by')
          .eq('user_id', userId)
          .order('event_date', ascending: true);

      return (response as List)
          .map((e) => CommunityEvent.fromJson({
        ...Map<String, dynamic>.from(e as Map),
        'status': 'approved',
      }))
          .toList();
    } catch (e) {
      debugPrint("Fetch My Approved Events Error: $e");
      return [];
    }
  }

  Future<List<CommunityEvent>> fetchUserRequests() async {
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('event_requests')
          .select('*, requests!inner(*)')
          .eq('requests.user_id', userId)
          .order('date', ascending: false);

      return _mapResponseToEventList(response);
    } catch (e) {
      debugPrint("Fetch User Requests Error: $e");
      return [];
    }
  }

  Future<List<CommunityEvent>> fetchJoinedEvents(String userId) async {
    try {
      final response = await supabase
          .from('event_participants')
          .select('event_id, events(*)')
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;

      return data
          .map((item) {
        if (item['events'] == null) return null;
        final eventMap = Map<String, dynamic>.from(item['events'] as Map);
        eventMap['status'] = 'approved';
        return CommunityEvent.fromJson(eventMap);
      })
          .whereType<CommunityEvent>()
          .toList();
    } catch (e) {
      debugPrint("Fetch Joined Events Error: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // 6. JOIN / LEAVE / REJECT / UTILITIES
  // ─────────────────────────────────────────────

  Future<void> joinEvent(String eventId, String userId) async {
    try {
      final event = await supabase
          .from('events')
          .select('participants, max_capacity, user_id')
          .eq('id', eventId)
          .single();

      if (event['user_id'] == userId) {
        throw Exception("As host, you're already participating!");
      }

      final int currentParticipants = event['participants'] ?? 0;
      final int maxCapacity = event['max_capacity'] ?? 20;

      if (currentParticipants >= maxCapacity) {
        throw Exception("Event is full!");
      }

      final existing = await supabase
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) throw Exception("You have already joined!");

      await supabase.from('event_participants').insert({
        'event_id': eventId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      await supabase
          .from('events')
          .update({'participants': currentParticipants + 1}).eq('id', eventId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveEvent(String eventId, String userId) async {
    try {
      final existing = await supabase
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        throw Exception("You haven't joined this event.");
      }

      await supabase
          .from('event_participants')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);

      final event = await supabase
          .from('events')
          .select('participants')
          .eq('id', eventId)
          .single();

      final int current = (event['participants'] as int?) ?? 0;
      await supabase
          .from('events')
          .update({'participants': (current - 1).clamp(0, 9999)}).eq(
          'id', eventId);
    } catch (e) {
      debugPrint("Leave Event Error: $e");
      rethrow;
    }
  }

  Future<bool> hasJoinedEvent(String eventId, String userId) async {
    try {
      final result = await supabase
          .from('event_participants')
          .select('event_id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> rejectRequest(String requestId, String reason) async {
    try {
      await supabase.from('requests').update({
        'status': 'rejected',
        'reject_reason': reason,
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 7. AVAILABILITY & SUGGESTIONS (UPDATED)
  // ─────────────────────────────────────────────

  // NEW HELPER: Checks if the Admin has manually blocked this facility
  Future<bool> isBlockedByAdmin(String facilityId, String date, String startTime, String endTime) async {
    try {
      final response = await supabase
          .from('facility_unavailable_slots')
          .select()
          .eq('facility_id', facilityId)
          .eq('block_date', date);

      final List blockedSlots = response as List;
      final int newStart = _timeToMinutes(startTime);
      final int newEnd = _timeToMinutes(endTime);

      for (var slot in blockedSlots) {
        final int blockStart = _timeToMinutes(slot['start_time'].toString());
        final int blockEnd = _timeToMinutes(slot['end_time'].toString());

        // Standard Overlap Logic
        if (newStart < blockEnd && newEnd > blockStart) {
          return true; // The time is blocked by an admin
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error checking admin blocks: $e");
      return false;
    }
  }

  Future<bool> isFacilityAvailable(
      String location, String date, String startTime, String endTime) async {

    // NOTE: In your Screen, you should call isBlockedByAdmin first.
    // If you want this method to do EVERYTHING, you'd need to pass
    // the facilityId here too. For now, this checks existing requests:

    final response = await supabase
        .from('event_requests')
        .select('start_time, end_time, requests!inner(status)')
        .eq('location', location)
        .eq('date', date)
        .filter('requests.status', 'in', '("approved","pending")');

    final int newStart = _timeToMinutes(startTime);
    final int newEnd = _timeToMinutes(endTime);
    const int bufferMinutes = 120; // 2 hours cleaning buffer

    for (var event in response) {
      final int existStart = _timeToMinutes(event['start_time']);
      final int existEnd = _timeToMinutes(event['end_time']);

      if (existStart < (newEnd + bufferMinutes) &&
          existEnd > (newStart - bufferMinutes)) {
        return false;
      }
    }
    return true;
  }

  Future<List<String>> getAvailableSlots({
    required String facilityId, // Changed from location to facilityId for accuracy
    required String location,
    required String date,
    required String openTime,
    required String closeTime,
  }) async {
    try {
      // 1. Fetch Confirmed Events
      final eventResponse = await supabase
          .from('events')
          .select('start_time, end_time')
          .eq('location', location)
          .eq('event_date', date);

      // 2. Fetch Admin Blocked Slots
      final blockResponse = await supabase
          .from('facility_unavailable_slots')
          .select('start_time, end_time')
          .eq('facility_id', facilityId)
          .eq('block_date', date);

      final List allBlocked = [...(eventResponse as List), ...(blockResponse as List)];

      int openMin = _timeToMinutes(openTime);
      int closeMin = _timeToMinutes(closeTime);
      const int cleaningBuffer = 120;

      // Map everything into Blocked Windows
      List<Map<String, int>> blockedWindows = allBlocked.map((e) {
        return {
          'start': _timeToMinutes(e['start_time'].toString()),
          'end': _timeToMinutes(e['end_time'].toString()) + cleaningBuffer,
        };
      }).toList();

      blockedWindows.sort((a, b) => a['start']!.compareTo(b['start']!));

      List<String> suggestions = [];
      int currentPos = openMin;

      for (var window in blockedWindows) {
        if (window['start']! - currentPos >= 60) {
          suggestions.add("${_minutesToDisplayTime(currentPos)} - ${_minutesToDisplayTime(window['start']!)}");
        }
        if (window['end']! > currentPos) {
          currentPos = window['end']!;
        }
      }

      if (closeMin - currentPos >= 60) {
        suggestions.add("${_minutesToDisplayTime(currentPos)} - ${_minutesToDisplayTime(closeMin)}");
      }

      return suggestions;
    } catch (e) {
      debugPrint("Error calculating slots: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // 8. HELPERS & MAPPING
  // ─────────────────────────────────────────────

  Future<CommunityEvent> fetchEventById(String eventId) async {
    final data =
    await supabase.from('events').select().eq('id', eventId).single();
    return CommunityEvent.fromJson(data);
  }

  List<CommunityEvent> _mapResponseToEventList(dynamic response) {
    if (response == null) return [];
    return (response as List)
        .map((json) => _mapSingleResponseToEvent(json))
        .toList();
  }

  CommunityEvent _mapSingleResponseToEvent(dynamic json) {
    final Map<String, dynamic> flattened =
    Map<String, dynamic>.from(json as Map);

    if (json['requests'] != null) {
      flattened['status'] = json['requests']['status'];
      flattened['description'] = json['requests']['description'];
      flattened['reject_reason'] = json['requests']['reject_reason'];
      flattened['user_id'] =
          flattened['user_id'] ?? json['requests']['user_id'];

      if (flattened['id'] == null) {
        flattened['id'] =
            (flattened['request_id'] ?? json['request_id']).toString();
      }
    }
    return CommunityEvent.fromJson(flattened);
  }

  int _timeToMinutes(String timeString) {
    if (timeString.isEmpty) return 0;
    try {
      // Splits "14:15:00" or "14:15" into a list
      final parts = timeString.split(':');

      // We only care about the first two parts (Hours and Minutes)
      if (parts.length < 2) return 0;

      final int hours = int.parse(parts[0]);
      final int minutes = int.parse(parts[1]);

      return (hours * 60) + minutes;
    } catch (e) {
      debugPrint("Error parsing time '$timeString': $e");
      return 0;
    }
  }

  String _minutesToDisplayTime(int totalMinutes) {
    int minutes = totalMinutes.clamp(0, 1439);
    int h = minutes ~/ 60;
    int m = minutes % 60;
    final period = h >= 12 ? "PM" : "AM";
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$displayH:${m.toString().padLeft(2, '0')} $period";
  }
}
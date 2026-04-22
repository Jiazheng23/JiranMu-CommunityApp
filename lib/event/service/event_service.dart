import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/event_model.dart';
import 'package:flutter/foundation.dart';

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

      // 1. Insert into master 'requests' table
      final response = await supabase.from('requests').insert({
        'user_id': userId,
        'type': 'booking',
        'title': eventData['title'],
        'description': eventData['description'],
        'status': (userRole == 'admin') ? 'approved' : 'pending',
      }).select().single();

      final String newRequestId = response['request_id'].toString();

      // 2. Insert into sub-table 'event_requests'
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

      // 3. If admin, promote to live 'events' table immediately
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

  /// Fetches live PUBLIC events for the community calendar.
  Future<List<CommunityEvent>> fetchAllEvents(
      {int? limit, bool upcomingOnly = true}) async {
    try {
      var query = supabase
          .from('events')
          .select(
          '*, requests!inner(status, user_id, description, reject_reason)')
          .eq('is_private', false);

      if (upcomingOnly) {
        final String today =
        DateTime.now().toIso8601String().split('T')[0];
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

  /// Fetches all approved events created by [userId].
  /// Used by the calendar screen to paint per-day indicators.
  /// Returns BOTH public and private events.
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

      // Rows in 'events' are always approved (they only get inserted on approval)
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

  /// Fetches all event requests (pending/approved/rejected) for the
  /// currently logged-in user. Used by ResidentEventHistoryScreen.
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

  /// Fetches all events the resident has joined via event_participants.
  /// Uses a left-join on requests so that events whose request row was
  /// cleaned up after promotion are still returned.
  Future<List<CommunityEvent>> fetchJoinedEvents(String userId) async {
    try {
      // Fetch participant rows with the full event data.
      // We do NOT require requests!inner so approved events that had
      // their request soft-deleted are still visible.
      final response = await supabase
          .from('event_participants')
          .select('event_id, events(*)')
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        if (item['events'] == null) return null;
        final eventMap =
        Map<String, dynamic>.from(item['events'] as Map);
        // All rows in events are approved
        eventMap['status'] = 'approved';
        return CommunityEvent.fromJson(eventMap);
      }).whereType<CommunityEvent>().toList();
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
          .update({'participants': currentParticipants + 1}).eq(
          'id', eventId);
    } catch (e) {
      rethrow;
    }
  }

  /// Allows a resident to leave an event they previously joined.
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

      // Decrement participant count (floor at 0)
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

  /// Returns true if [userId] has already joined [eventId].
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

  Future<bool> isFacilityAvailable(
      String location, String date, String startTime, String endTime) async {
    final response = await supabase
        .from('event_requests')
        .select('start_time, end_time, requests!inner(status)')
        .eq('location', location)
        .eq('date', date)
        .filter('requests.status', 'in', '("approved","pending")');

    final int newStart = _timeToMinutes(startTime);
    final int newEnd = _timeToMinutes(endTime);

    for (var event in response) {
      final int existStart = _timeToMinutes(event['start_time']);
      final int existEnd = _timeToMinutes(event['end_time']);
      if (newStart < existEnd && newEnd > existStart) return false;
    }
    return true;
  }

  Future<CommunityEvent> fetchEventById(String eventId) async {
    final data = await supabase
        .from('events')
        .select()
        .eq('id', eventId)
        .single();
    return CommunityEvent.fromJson(data);
  }

  // ─────────────────────────────────────────────
  // 7. MAPPING HELPERS
  // ─────────────────────────────────────────────

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

      // Use request_id as id when main 'id' is null (history/pending views)
      if (flattened['id'] == null) {
        flattened['id'] =
            (flattened['request_id'] ?? json['request_id']).toString();
      }
    }
    return CommunityEvent.fromJson(flattened);
  }

  int _timeToMinutes(String timeString) {
    if (timeString.isEmpty) return 0;
    final parts = timeString.split(':');
    return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
  }
}
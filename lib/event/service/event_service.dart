import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/event_model.dart';
import 'package:flutter/foundation.dart';

class EventService {
  final supabase = Supabase.instance.client;

  // --- 1. UPLOAD IMAGE ---
  Future<String?> uploadEventImage(File imageFile) async {
    try {
      final String fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  // --- 2. FACILITY METHODS ---
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

  // --- 3. CREATE EVENT REQUEST ---
  Future<void> createEvent({
    required Map<String, dynamic> eventData,
    required String userRole,
  }) async {
    try {
      final String? userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User must be logged in to create events.");

      // 1. Insert into Master 'requests' table
      final response = await supabase.from('requests').insert({
        'user_id': userId,
        'type': 'booking',
        'title': eventData['title'],
        'description': eventData['description'],
        'status': (userRole == 'admin') ? 'approved' : 'pending',
      }).select().single();

      final String newRequestId = response['request_id'].toString();

      // 2. Insert into Sub-Table 'event_requests'
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

      // 3. If Admin, promote to live 'events' table immediately
      if (userRole == 'admin') {
        await approveAndPromoteRequest(newRequestId);
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
      rethrow;
    }
  }

  // --- 4. APPROVE & PROMOTE ---
  Future<void> approveAndPromoteRequest(String requestId) async {
    try {
      // Update Master table status
      await supabase.from('requests').update({
        'status': 'approved',
        'respond_time': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);

      // Fetch details from sub-table to move to 'events'
      final details = await supabase
          .from('event_requests')
          .select('*, requests!inner(user_id, description)')
          .eq('request_id', requestId)
          .single();

      // Promotion logic: Uses requestId as the primary ID for 'events'
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

  // --- 5. FETCHING METHODS ---

  /// Fetches live events for the Calendar.
  Future<List<CommunityEvent>> fetchAllEvents({int? limit, bool upcomingOnly = true}) async {
    try {
      var query = supabase
          .from('events')
          .select('*, requests!inner(status, user_id, description, reject_reason)')
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

  /// Fetches all requests (Pending/Approved/Rejected) for a specific user.
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
          .select('*, events(*, requests!inner(status, user_id, description))')
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        if (item['events'] == null) return null;
        return _mapSingleResponseToEvent(item['events']);
      }).whereType<CommunityEvent>().toList();
    } catch (e) {
      debugPrint("Fetch Joined Events Error: $e");
      return [];
    }
  }

  // --- 6. JOIN, REJECT & UTILITIES ---

  Future<void> joinEvent(String eventId, String userId) async {
    try {
      final event = await supabase
          .from('events')
          .select('participants, max_capacity, user_id')
          .eq('id', eventId)
          .single();

      if (event['user_id'] == userId) throw Exception("As host, you're already participating!");

      int currentParticipants = event['participants'] ?? 0;
      int maxCapacity = event['max_capacity'] ?? 20;

      if (currentParticipants >= maxCapacity) throw Exception("Event is full!");

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
          .update({'participants': currentParticipants + 1})
          .eq('id', eventId);
    } catch (e) {
      rethrow;
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

  Future<bool> isFacilityAvailable(String location, String date, String startTime, String endTime) async {
    final response = await supabase
        .from('event_requests')
        .select('start_time, end_time, requests!inner(status)')
        .eq('location', location)
        .eq('date', date)
        .filter('requests.status', 'in', '("approved","pending")');

    int newStart = _timeToMinutes(startTime);
    int newEnd = _timeToMinutes(endTime);

    for (var event in response) {
      int existStart = _timeToMinutes(event['start_time']);
      int existEnd = _timeToMinutes(event['end_time']);
      if (newStart < existEnd && newEnd > existStart) return false;
    }
    return true;
  }

  // --- 7. MAPPING HELPERS ---

  List<CommunityEvent> _mapResponseToEventList(dynamic response) {
    if (response == null) return [];
    return (response as List).map((json) => _mapSingleResponseToEvent(json)).toList();
  }

  CommunityEvent _mapSingleResponseToEvent(dynamic json) {
    final Map<String, dynamic> flattened = Map<String, dynamic>.from(json);

    if (json['requests'] != null) {
      flattened['status'] = json['requests']['status'];
      flattened['description'] = json['requests']['description'];
      flattened['reject_reason'] = json['requests']['reject_reason'];
      flattened['user_id'] = flattened['user_id'] ?? json['requests']['user_id'];

      // Crucial: Use request_id if the main 'id' is null (for history/pending views)
      if (flattened['id'] == null) {
        flattened['id'] = (flattened['request_id'] ?? json['request_id']).toString();
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
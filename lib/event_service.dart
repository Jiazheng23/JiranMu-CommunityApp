import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_model.dart';

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
      print("Upload Error: $e");
      return null;
    }
  }

  // --- 2. CREATE EVENT REQUEST ---
  Future<void> createEvent({
    required Map<String, dynamic> eventData,
    required String userRole,
  }) async {
    try {
      final String? userId = supabase.auth.currentUser?.id;

      if (userId == null) throw Exception("User must be logged in to create events.");

      // STEP A: Insert into Master 'requests' table
      final List<dynamic> response = await supabase.from('requests').insert({
        'user_id': userId,
        'type': 'booking',
        'title': eventData['title'],
        'description': eventData['description'],
        'status': (userRole == 'admin') ? 'approved' : 'pending',
      }).select();

      if (response.isEmpty) throw Exception("No data returned from 'requests' table.");

      final String newRequestId = response[0]['request_id'].toString();

      // STEP B: Insert into Sub-Table 'event_requests'
      await supabase.from('event_requests').insert({
        'request_id': newRequestId,
        'event_title': eventData['title'],
        'location': eventData['location'],
        'date': eventData['event_date'],
        'start_time': eventData['start_time'],
        'end_time': eventData['end_time'],
        'image_url': eventData['image_url'],
        'participants': 0,
        'max_capacity': eventData['max_capacity'] ?? 20, // UPDATED: Added Max Capacity
        'created_by_name': eventData['created_by_name'] ?? 'Resident',
        'is_private': eventData['is_private'] ?? false,
      });

      if (userRole == 'admin') {
        await approveAndPromoteRequest(newRequestId);
      }
    } catch (e) {
      print("Submit Error: $e");
      rethrow;
    }
  }

  // --- 3. APPROVE & PROMOTE ---
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
        'max_capacity': details['max_capacity'] ?? 20, // UPDATED: Added Max Capacity
        'participants': 0,
      });
    } catch (e) {
      print("Approval Error: $e");
      rethrow;
    }
  }

  // --- 4. FETCHING METHODS ---

  // Fetches approved public events for the calendar
  Future<List<CommunityEvent>> fetchAllEvents() async {
    final response = await supabase
        .from('events')
        .select('*, requests!inner(status, user_id, description)')
        .eq('is_private', false)
        .order('event_date', ascending: true);

    return (response as List).map((json) => CommunityEvent.fromJson(json)).toList();
  }

  // Fetches pending proposals for Admin view
  Future<List<CommunityEvent>> fetchPendingEvents() async {
    final response = await supabase
        .from('event_requests')
        .select('*, requests!inner(status, created_at, user_id, description)')
        .eq('requests.status', 'pending');

    return (response as List).map((json) => CommunityEvent.fromJson(json)).toList();
  }

  // NEW: Fetch only the logged-in user's requests for the History Page
  Future<List<CommunityEvent>> fetchUserRequests() async {
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('event_requests')
        .select('*, requests!inner(*)')
        .eq('requests.user_id', userId)
        .order('date', ascending: false);

    return (response as List).map((json) => CommunityEvent.fromJson(json)).toList();
  }

  // --- 5. JOIN EVENT ---
  Future<void> joinEvent(String eventId, String userId) async {
    try {
      // 1. Check Capacity first
      final event = await supabase
          .from('events')
          .select('participants, max_capacity')
          .eq('id', eventId)
          .single();

      if (event['participants'] >= event['max_capacity']) {
        throw Exception("Event is full!");
      }

      // 2. Check for existing registration
      final existing = await supabase
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        throw Exception("You have already joined this event!");
      }

      // 3. Insert participant
      await supabase.from('event_participants').insert({
        'event_id': eventId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Note: You should ideally have a Database Trigger in Supabase
      // to increment the 'participants' count in the 'events' table automatically.
    } catch (e) {
      print("Join Event Error: $e");
      rethrow;
    }
  }

  // --- 6. REJECT REQUEST ---
  Future<void> rejectRequest(String requestId, String reason) async {
    await supabase.from('requests').update({
      'status': 'rejected',
      'reject_reason': reason,
      'respond_time': DateTime.now().toIso8601String(),
    }).eq('request_id', requestId);
  }

  // --- 7. UTILITIES ---
  Future<bool> isFacilityAvailable(
      String location, String date, String startTime, String endTime) async {
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

  int _timeToMinutes(String timeString) {
    if (timeString.isEmpty) return 0;
    try {
      final parts = timeString.split(':');
      return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }
}
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_model.dart';

class EventService {
  final supabase = Supabase.instance.client;

  // 1. UPLOAD IMAGE: Using your existing 'event_images' bucket
  Future<String?> uploadEventImage(File imageFile) async {
    try {
      // Create a unique filename using timestamp
      final String fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to your existing bucket
      await supabase.storage.from('event_images').upload(
        fileName,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

      // Return the Public URL
      return supabase.storage.from('event_images').getPublicUrl(fileName);
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  // 2. CREATE EVENT: Sets status based on Role ('admin' vs 'resident')
  Future<void> createEvent({
    required Map<String, dynamic> eventData,
    required String userRole,
  }) async {
    final String initialStatus = (userRole == 'admin') ? 'approved' : 'pending';

    final Map<String, dynamic> finalData = {
      ...eventData,
      'status': initialStatus,
      'created_at': DateTime.now().toIso8601String(),
    };

    await supabase.from('events').insert(finalData);
  }

  // 3. FETCH APPROVED: For the Resident Calendar
  Future<List<CommunityEvent>> fetchAllEvents() async {
    final response = await supabase
        .from('events')
        .select()
        .eq('status', 'approved')
        .order('event_date', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => CommunityEvent.fromJson(json)).toList();
  }

  // 4. FETCH PENDING: For the Admin Approval Screen
  Future<List<CommunityEvent>> fetchPendingEvents() async {
    final response = await supabase
        .from('events')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((json) => CommunityEvent.fromJson(json)).toList();
  }

  // 5. ADMIN ACTION: Approve or Reject
  Future<void> updateEventStatus(int eventId, String newStatus) async {
    await supabase.from('events').update({'status': newStatus}).eq('id', eventId);
  }

  // 6. FETCH JOINED: For "My Events"
  Future<List<CommunityEvent>> fetchMyJoinedEvents(String userEmail) async {
    final response = await supabase
        .from('event_participants')
        .select('events (*)')
        .eq('user_email', userEmail);

    final data = response as List<dynamic>;
    return data
        .where((item) => item['events'] != null)
        .map((item) => CommunityEvent.fromJson(item['events']))
        .toList();
  }

  // 7. JOIN EVENT
  Future<void> joinEvent(int eventId, String userEmail) async {
    try {
      await supabase.from('event_participants').insert({
        'event_id': eventId,
        'user_email': userEmail,
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("You have already joined this event.");
    }
  }
}
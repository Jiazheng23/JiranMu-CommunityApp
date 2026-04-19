import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../service/event_service.dart';
import 'event_details_screen.dart';

class MyJoinedEventsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentRole;

  const MyJoinedEventsScreen({
    super.key,
    required this.currentUserId,
    required this.currentRole
  });

  @override
  State<MyJoinedEventsScreen> createState() => _MyJoinedEventsScreenState();
}

class _MyJoinedEventsScreenState extends State<MyJoinedEventsScreen> {
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);
  final EventService _eventService = EventService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Matching your creamBg
      appBar: AppBar(
        title: const Text("My Joined Events",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: cork,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: FutureBuilder<List<CommunityEvent>>(
        future: _eventService.fetchJoinedEvents(widget.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: apricot));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final joinedEvents = snapshot.data ?? [];

          if (joinedEvents.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: joinedEvents.length,
            itemBuilder: (context, index) {
              final event = joinedEvents[index];
              return _buildJoinedEventCard(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildJoinedEventCard(CommunityEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: event.imageUrl != null && event.imageUrl!.isNotEmpty
              ? Image.network(event.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
              : Container(width: 60, height: 60, color: apricot.withOpacity(0.2), child: Icon(Icons.event, color: cork)),
        ),
        title: Text(event.title,
            style: TextStyle(fontWeight: FontWeight.bold, color: cork, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: apricot),
                const SizedBox(width: 5),
                Text("${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}"),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: apricot),
                const SizedBox(width: 5),
                Text(event.startTime),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: cork),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(
                event: event,
                currentRole: widget.currentRole,
                currentUserId: widget.currentUserId,
                onRefresh: () => setState(() {}), // Refresh list if they leave the event
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 80, color: cork.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("You haven't joined any events yet!",
              style: TextStyle(color: cork, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Explore Calendar", style: TextStyle(color: apricot)),
          )
        ],
      ),
    );
  }
}
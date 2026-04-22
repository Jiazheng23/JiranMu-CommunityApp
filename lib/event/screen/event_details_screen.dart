import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../service/event_service.dart';

class EventDetailsScreen extends StatelessWidget {
  final CommunityEvent event;
  final String currentRole;
  final String currentUserId;
  final VoidCallback onRefresh;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.currentRole,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final Color cork = const Color(0xFFAD8762);
    final Color apricot = const Color(0xFFFFB38A);
    final bool isHost = event.createdBy == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event Details",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: cork,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          if (event.status == 'approved')
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: "Share Event",
              onPressed: () {
                // TODO: Implement share_plus logic later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sharing function coming soon!")),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header
            event.imageUrl != null && event.imageUrl!.isNotEmpty
                ? Image.network(event.imageUrl!, height: 250, width: double.infinity, fit: BoxFit.cover)
                : Container(
              height: 250,
              width: double.infinity,
              color: cork.withOpacity(0.1),
              child: Icon(Icons.image, size: 100, color: cork),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  if (event.status != 'approved')
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.status == 'pending' ? Colors.orange.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          color: event.status == 'pending' ? Colors.orange.shade800 : Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  Text(event.title,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cork)),
                  const SizedBox(height: 10),

                  _detailRow(Icons.person, "Organized by", event.createdByDisplayName),
                  _detailRow(Icons.location_on, "Location", event.location),
                  _detailRow(Icons.calendar_today, "Date", event.eventDate.toString().split(' ')[0]),
                  _detailRow(Icons.access_time, "Time", "${event.startTime} - ${event.endTime}"),
                  _detailRow(Icons.group, "Capacity", "${event.participants} / ${event.maxCapacity}"),

                  const Divider(height: 40),
                  Text("Description",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cork)),
                  const SizedBox(height: 10),
                  Text(event.description,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),

                  const SizedBox(height: 40),

                  // Action Buttons: Only shows Join if it's not the user's own event and is approved
                  if (event.status == 'approved' && !isHost)
                    _joinButton(context, apricot)
                  else if (isHost)
                    _hostIndicator(cork)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFB38A), size: 20),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _hostIndicator(Color color) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 10),
        Center(
          child: Text(
            "You are the host of this event",
            style: TextStyle(color: color, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
          ),
        ),
        if (event.status == 'approved')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "Invite residents using the share icon in the top right!",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _joinButton(BuildContext context, Color color) {
    final bool isFull = event.participants >= event.maxCapacity;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFull ? null : () async {
          try {
            await EventService().joinEvent(event.id, currentUserId);
            onRefresh();
            // Show success message before popping
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Successfully joined the event!")),
            );
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
            isFull ? "Event Full" : "Join Event",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
}
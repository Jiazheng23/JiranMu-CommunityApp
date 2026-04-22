import 'package:assignment/event/screen/share_event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:assignment/event/model/event_model.dart';
import '../service/event_service.dart';

class EventDetailsScreen extends StatelessWidget {
  final CommunityEvent event;
  final String currentRole;
  final String currentUserId;

  /// The display name of the current user — needed so the share sheet
  /// can send messages as them.
  final String currentUserName;

  final VoidCallback onRefresh;

  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.currentRole,
    required this.currentUserId,
    required this.currentUserName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final Color cork = const Color(0xFFAD8762);
    final Color apricot = const Color(0xFFFFB38A);

    final bool isHost =
        event.userId == currentUserId ||
            (event.createdBy != null && event.createdBy == currentUserId);

    final bool isApproved = event.status == 'approved';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Event Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: cork,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          if (isApproved && (isHost || !event.isPrivate))
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () => _showShareSheet(context),
              tooltip: 'Share',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image header ───────────────────
            Stack(
              children: [
                event.imageUrl != null && event.imageUrl!.isNotEmpty
                    ? Image.network(
                  event.imageUrl!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
                    : Container(
                  height: 250,
                  width: double.infinity,
                  color: cork.withOpacity(0.1),
                  child: Icon(Icons.image, size: 100, color: cork),
                ),
                // Privacy badge on image
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: event.isPrivate
                          ? Colors.purple.withOpacity(0.85)
                          : Colors.blue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          event.isPrivate
                              ? Icons.lock_outline
                              : Icons.public,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          event.isPrivate ? 'Private' : 'Public',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge (for non-approved states)
                  if (!isApproved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.status == 'pending'
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          color: event.status == 'pending'
                              ? Colors.orange.shade800
                              : Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Title
                  Text(
                    event.title,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cork),
                  ),
                  const SizedBox(height: 10),

                  // Details
                  _detailRow(
                    Icons.person,
                    "Organised by",
                    event.createdByName.isNotEmpty
                        ? event.createdByName
                        : 'Resident',
                  ),
                  _detailRow(Icons.location_on, "Location", event.location),
                  _detailRow(
                    Icons.calendar_today,
                    "Date",
                    event.eventDate.toString().split(' ')[0],
                  ),
                  _detailRow(
                    Icons.access_time,
                    "Time",
                    "${event.startTime} - ${event.endTime}",
                  ),
                  _detailRow(
                    Icons.group,
                    "Capacity",
                    "${event.participants ?? 0} / ${event.maxCapacity}",
                  ),

                  const Divider(height: 40),

                  Text(
                    "Description",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cork),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.description.isNotEmpty
                        ? event.description
                        : 'No description provided.',
                    style: const TextStyle(
                        fontSize: 16, color: Colors.black87, height: 1.5),
                  ),

                  const SizedBox(height: 40),

                  // ── Action section ──────────────────────────
                  if (isApproved && !isHost)
                    _joinSection(context, cork, apricot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share sheet ───────────────────────────────

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareEventSheet(
        event: event,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFB38A), size: 20),
          const SizedBox(width: 10),
          Text("$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ── Join section (non-host, approved) ─────────
  Widget _joinSection(BuildContext context, Color cork, Color apricot) {
    final int participantCount = event.participants ?? 0;
    final bool isFull = participantCount >= event.maxCapacity;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFull
            ? null
            : () async {
          try {
            await EventService().joinEvent(event.id, currentUserId);
            onRefresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Successfully joined the event!")),
            );
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      e.toString().replaceAll("Exception: ", ""))),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: apricot,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          isFull ? "Event Full" : "Join Event",
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
import 'package:assignment/event/screen/share_event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:assignment/event/model/event_model.dart';
import 'package:assignment/event/service/event_service.dart';

class EventDetailsScreen extends StatelessWidget {
  final CommunityEvent event;
  final String currentRole;
  final String currentUserId;
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
    // ── NEW THEME COLORS ──────────────────────────────
    const Color primaryRed = Color(0xFF9A4B3C); // Deep Red/Brown
    const Color accentPeach = Color(0xFFFC9D7E); // Apricot/Peach
    const Color bgColor = Color(0xFFF5F1ED);    // Beige Background

    final bool isHost =
        event.userId == currentUserId ||
            (event.createdBy != null && event.createdBy == currentUserId);

    final bool isApproved = event.status == 'approved';

    return Scaffold(
      backgroundColor: bgColor, // Updated background
      appBar: AppBar(
        title: const Text(
          "Event Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryRed, // Updated AppBar
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
                  color: primaryRed.withOpacity(0.05),
                  child: Icon(Icons.image, size: 100, color: primaryRed.withOpacity(0.2)),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          event.isPrivate ? Icons.lock_outline : Icons.public,
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
                  if (!isApproved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: event.status == 'pending'
                            ? Colors.orange.shade50
                            : primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: TextStyle(
                          color: event.status == 'pending'
                              ? Colors.orange.shade800
                              : primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B)), // Dark Text
                  ),
                  const SizedBox(height: 15),

                  _detailRow(Icons.person, "Organised by",
                      event.createdByName.isNotEmpty ? event.createdByName : 'Resident', accentPeach, primaryRed),
                  _detailRow(Icons.location_on, "Location", event.location, accentPeach, primaryRed),
                  _detailRow(Icons.calendar_today, "Date",
                      event.eventDate.toString().split(' ')[0], accentPeach, primaryRed),
                  _detailRow(Icons.access_time, "Time",
                      "${event.startTime} - ${event.endTime}", accentPeach, primaryRed),
                  _detailRow(Icons.group, "Capacity",
                      "${event.participants ?? 0} / ${event.maxCapacity}", accentPeach, primaryRed),

                  const Divider(height: 40, thickness: 1),

                  const Text(
                    "Description",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryRed), // Primary theme color
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

                  if (isApproved && !isHost)
                    _joinSection(context, primaryRed, accentPeach),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _detailRow(IconData icon, String label, String value, Color iconColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text("$label: ",
              style: TextStyle(fontWeight: FontWeight.bold, color: labelColor.withOpacity(0.8))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _joinSection(BuildContext context, Color primary, Color accent) {
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
          backgroundColor: accent, // Peach color
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          isFull ? "Event Full" : "Join Event",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
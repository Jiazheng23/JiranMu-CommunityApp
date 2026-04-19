import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/event_model.dart';
import '../service/event_service.dart';

class ResidentEventHistoryScreen extends StatefulWidget {
  const ResidentEventHistoryScreen({super.key});

  @override
  State<ResidentEventHistoryScreen> createState() => _ResidentEventHistoryScreenState();
}

class _ResidentEventHistoryScreenState extends State<ResidentEventHistoryScreen> {
  final EventService _eventService = EventService();

  // Theme Colors
  final Color cork = const Color(0xFFAD8762);
  final Color apricot = const Color(0xFFFFB38A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Light cream background
      appBar: AppBar(
        title: const Text(
          "My Event History",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: cork,
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Triggers a rebuild to fetch fresh data from Supabase
          setState(() {});
        },
        color: apricot,
        child: FutureBuilder<List<CommunityEvent>>(
          future: _eventService.fetchUserRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center),
                ),
              );
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final event = requests[index];
                return _buildHistoryCard(event);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(CommunityEvent event) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cork,
                    ),
                  ),
                ),
                _buildStatusBadge(event.status),
              ],
            ),
            const Divider(height: 24, thickness: 1),

            // Event Details
            _buildIconInfo(Icons.location_on_outlined, event.location),
            const SizedBox(height: 8),
            _buildIconInfo(
              Icons.calendar_month_outlined,
              DateFormat('dd MMM yyyy').format(event.eventDate),
            ),
            const SizedBox(height: 8),
            _buildIconInfo(
              Icons.access_time_outlined,
              "${event.startTime} - ${event.endTime}",
            ),
            const SizedBox(height: 8),
            _buildIconInfo(Icons.people_outline, "Capacity: ${event.maxCapacity} people"),

            // REJECTED REASON SECTION
            if (event.status.toLowerCase() == 'rejected') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.feedback_outlined, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Admin Feedback",
                          style: TextStyle(
                            color: Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.rejectReason ?? "No specific feedback provided.",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // APPROVED MESSAGE
            if (event.status.toLowerCase() == 'approved') ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "This event is now live on the calendar!",
                    style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: apricot),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange; // Pending
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 80, color: cork.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "No event requests found",
            style: TextStyle(color: cork, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Your submitted proposals will appear here.",
            style: TextStyle(color: cork.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
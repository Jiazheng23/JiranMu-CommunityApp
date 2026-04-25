import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 1. Added Import
import '../model/event_model.dart';
import '../service/event_service.dart';
import 'share_event_sheet.dart';

class ResidentEventHistoryScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ResidentEventHistoryScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ResidentEventHistoryScreen> createState() =>
      _ResidentEventHistoryScreenState();
}

class _ResidentEventHistoryScreenState
    extends State<ResidentEventHistoryScreen> {
  final EventService _eventService = EventService();
  List<String> _seenRequestIds = []; // 2. Track seen IDs locally

  // ── THEME COLORS ──────────────────────────────
  final Color primaryRed = const Color(0xFF9A4B3C); // Deep Red/Brown
  final Color accentPeach = const Color(0xFFFC9D7E); // Apricot/Peach
  final Color bgColor = const Color(0xFFF5F1ED);    // Beige/Off-white

  @override
  void initState() {
    super.initState();
    _loadSeenIds();
  }

  // 3. Load the list of IDs the user has already "seen"
  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenRequestIds = prefs.getStringList('seen_request_ids') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "My Event History",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryRed,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSeenIds();
          setState(() {});
        },
        color: accentPeach,
        child: FutureBuilder<List<CommunityEvent>>(
          future: _eventService.fetchUserRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: accentPeach));
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Error loading history: ${snapshot.error}",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final requests = snapshot.data ?? [];

            if (requests.isNotEmpty) {
              requests.sort((a, b) {
                bool aIsPending = a.status.toLowerCase() == 'pending';
                bool bIsPending = b.status.toLowerCase() == 'pending';
                if (aIsPending && !bIsPending) return -1;
                if (!aIsPending && bIsPending) return 1;
                return b.eventDate.compareTo(a.eventDate);
              });
            }

            if (requests.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final event = requests[index];
                // 4. Determine if this specific card should show a "NEW" badge
                final bool isNewUpdate = !_seenRequestIds.contains(event.id) &&
                    event.status.toLowerCase() != 'pending';

                return _buildHistoryCard(event, isNewUpdate);
              },
            );
          },
        ),
      ),
    );
  }

  void _showShareSheet(CommunityEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ShareEventSheet(
        event: event,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
  }

  // 5. Updated buildHistoryCard to accept the isNewUpdate boolean
  Widget _buildHistoryCard(CommunityEvent event, bool isNewUpdate) {
    final bool isApproved = event.status.toLowerCase() == 'approved';
    final bool isRejected = event.status.toLowerCase() == 'rejected';
    final bool isPrivate = event.isPrivate;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 6. Added NEW Badge next to title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                          ),
                          if (isNewUpdate)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "NEW",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? Colors.purple.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPrivate
                                ? Colors.purple.withOpacity(0.4)
                                : Colors.blue.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPrivate ? Icons.lock_outline : Icons.public,
                              size: 11,
                              color: isPrivate ? Colors.purple : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPrivate ? 'Private' : 'Public',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isPrivate
                                    ? Colors.purple
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(event.status),
                    if (isApproved) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showShareSheet(event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentPeach.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border:
                            Border.all(color: accentPeach.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.share_outlined, size: 13, color: primaryRed),
                              const SizedBox(width: 4),
                              Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primaryRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),

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
            _buildIconInfo(Icons.people_outline,
                "Max Capacity: ${event.maxCapacity} people"),

            if (isApproved) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: Colors.blue.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPrivate ? Icons.lock_outline : Icons.public,
                      color: isPrivate ? Colors.purple : Colors.blue,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPrivate
                            ? 'Private event · Share via direct messages only'
                            : 'Public event · Share via direct messages or group chats',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          isPrivate ? Colors.purple : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isRejected) ...[
              const SizedBox(height: 16),
              _buildFeedbackBox(
                title: "Admin Feedback",
                message:
                event.rejectReason ?? "No specific feedback provided.",
                baseColor: Colors.red,
              ),
            ],

            if (isApproved) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your event is live on the community calendar!",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS REMAIN UNCHANGED ---

  Widget _buildIconInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accentPeach),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w400),
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
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeedbackBox({required String title, required String message, required Color baseColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: baseColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback_outlined, color: baseColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: baseColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined,
              size: 80, color: primaryRed.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "No requests yet",
            style: TextStyle(
                color: primaryRed, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "When you propose an event, it will appear here.",
            style: TextStyle(color: primaryRed.withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
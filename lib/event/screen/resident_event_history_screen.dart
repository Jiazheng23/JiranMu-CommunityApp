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

  String _statusFilter = 'all'; // Current filter state

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
      body: Column( // ── Wrapped in a Column to hold the Filter Bar ──
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
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
                    return _buildErrorState(snapshot.error.toString());
                  }

                  final allRequests = snapshot.data ?? [];

                  // ── APPLY FILTER LOGIC ──────────────────────────────
                  final filteredRequests = allRequests.where((e) {
                    if (_statusFilter == 'all') return true;
                    return e.status.toLowerCase() == _statusFilter;
                  }).toList();

                  if (filteredRequests.isNotEmpty) {
                    filteredRequests.sort((a, b) {
                      bool aIsPending = a.status.toLowerCase() == 'pending';
                      bool bIsPending = b.status.toLowerCase() == 'pending';
                      if (aIsPending && !bIsPending) return -1;
                      if (!aIsPending && bIsPending) return 1;
                      return b.eventDate.compareTo(a.eventDate);
                    });
                  }

                  if (filteredRequests.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredRequests.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final event = filteredRequests[index];
                      final bool isNewUpdate = !_seenRequestIds.contains(event.id) &&
                          event.status.toLowerCase() != 'pending';
                      return _buildHistoryCard(event, isNewUpdate);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── NEW FILTER BAR UI ──────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _filterPill('all', 'All'),
          const SizedBox(width: 8),
          _filterPill('pending', 'Pending'),
          const SizedBox(width: 8),
          _filterPill('approved', 'Approved'),
          const SizedBox(width: 8),
          _filterPill('rejected', 'Rejected'),
        ],
      ),
    );
  }

  Widget _filterPill(String value, String label) {
    final isSelected = _statusFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _statusFilter = value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryRed : Colors.white,
            borderRadius: BorderRadius.circular(20),
            // Added the sleek black outline you liked
            border: Border.all(
              color: isSelected ? primaryRed : Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? primaryRed.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : primaryRed,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
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
  // 1. Updated buildHistoryCard: Now clickable to show details
  Widget _buildHistoryCard(CommunityEvent event, bool isNewUpdate) {
    final String status = event.status.toLowerCase();
    Color statusColor;
    switch (status) {
      case 'approved': statusColor = const Color(0xFF6B8E6B); break;
      case 'rejected': statusColor = const Color(0xFFC67B75); break;
      default:         statusColor = const Color(0xFFD4A847);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEventDetails(event), // NEW: Shows details on click
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // CIRCLE PICTURE
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: bgColor,
                    backgroundImage: (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                        ? NetworkImage(event.imageUrl!)
                        : null,
                    child: (event.imageUrl == null || event.imageUrl!.isEmpty)
                        ? Icon(Icons.event_note_outlined, color: primaryRed, size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // CENTER CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2B2B2B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNewUpdate) _buildNewBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(event.eventDate),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // STATUS BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2. NEW: The Event Details View (Admin-style but for Residents)
  void _showEventDetails(CommunityEvent event) {
    final bool isApproved = event.status.toLowerCase() == 'approved';
    final bool isRejected = event.status.toLowerCase() == 'rejected';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Title and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryRed),
                    ),
                  ),
                  _buildStatusBadge(event.status),
                ],
              ),
              const SizedBox(height: 20),

              // Image (if available)
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(image: NetworkImage(event.imageUrl!), fit: BoxFit.cover),
                  ),
                ),

              const Text("Event Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              _buildIconInfo(Icons.location_on_outlined, event.location),
              const SizedBox(height: 8),
              _buildIconInfo(Icons.calendar_month_outlined, DateFormat('EEEE, dd MMMM yyyy').format(event.eventDate)),
              const SizedBox(height: 8),
              _buildIconInfo(Icons.access_time_outlined, "${event.startTime} - ${event.endTime}"),
              const SizedBox(height: 8),
              _buildIconInfo(Icons.people_outline, "Max Capacity: ${event.maxCapacity} people"),
              const SizedBox(height: 8),
              _buildIconInfo(event.isPrivate ? Icons.lock_outline : Icons.public, event.isPrivate ? "Private Event" : "Public Event"),

              const Divider(height: 40),

              if (event.description != null && event.description!.isNotEmpty) ...[
                const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(event.description!, style: const TextStyle(color: Colors.black54, height: 1.5)),
                const SizedBox(height: 20),
              ],

              if (isRejected)
                _buildFeedbackBox(
                  title: "Rejection Reason",
                  message: event.rejectReason ?? "No feedback provided.",
                  baseColor: Colors.red,
                ),

              if (isApproved)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showShareSheet(event);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text("Share Event", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for the "NEW" badge
  Widget _buildNewBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
      child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}